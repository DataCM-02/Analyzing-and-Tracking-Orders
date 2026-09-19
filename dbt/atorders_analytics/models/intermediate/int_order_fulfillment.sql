with orders as (

    select
        order_id,
        order_status,
        promised_delivery_at
    from {{ ref('stg_ecommerce__orders') }}

),

ordered_items as (

    select
        order_id,
        count(*) as order_item_count,
        count(distinct product_id) as product_count,
        sum(quantity) as ordered_quantity
    from {{ ref('stg_ecommerce__order_items') }}
    group by order_id

),

shipment_summary as (

    select
        order_id,
        count(*) as shipment_count,
        count(*) filter (
            where shipment_status = 'delivered'
        ) as delivered_shipment_count,
        sum(delivery_attempts) as delivery_attempt_count,
        min(shipped_at) as first_shipped_at,
        min(in_transit_at) as first_in_transit_at,
        max(delivered_at) as last_delivered_at
    from {{ ref('stg_ecommerce__shipments') }}
    group by order_id

),

shipment_item_summary as (

    select
        s.order_id,
        sum(si.quantity_shipped) as shipped_quantity,
        sum(si.quantity_delivered) as delivered_quantity
    from {{ ref('stg_ecommerce__shipment_items') }} as si
    inner join {{ ref('stg_ecommerce__shipments') }} as s
        on si.shipment_id = s.shipment_id
    group by s.order_id

),

fulfillment as (

    select
        o.order_id,
        o.order_status,
        o.promised_delivery_at,

        coalesce(oi.order_item_count, 0) as order_item_count,
        coalesce(oi.product_count, 0) as product_count,
        coalesce(oi.ordered_quantity, 0) as ordered_quantity,

        coalesce(ss.shipment_count, 0) as shipment_count,
        coalesce(
            ss.delivered_shipment_count,
            0
        ) as delivered_shipment_count,
        coalesce(
            ss.delivery_attempt_count,
            0
        ) as delivery_attempt_count,

        ss.first_shipped_at,
        ss.first_in_transit_at,
        ss.last_delivered_at,

        coalesce(sis.shipped_quantity, 0) as shipped_quantity,
        coalesce(sis.delivered_quantity, 0) as delivered_quantity

    from orders as o
    left join ordered_items as oi
        on o.order_id = oi.order_id
    left join shipment_summary as ss
        on o.order_id = ss.order_id
    left join shipment_item_summary as sis
        on o.order_id = sis.order_id

)

select
    *,

    greatest(
        ordered_quantity - delivered_quantity,
        0
    ) as unfulfilled_quantity,

    round(
        (
            100.0
            * delivered_quantity
            / nullif(ordered_quantity, 0)
        )::numeric,
        2
    ) as fulfillment_rate_percentage,

    shipped_quantity = ordered_quantity as is_fully_shipped,

    delivered_quantity > 0
        and delivered_quantity < ordered_quantity
        as has_partial_delivery,

    case
        when order_status = 'delivered'
            then delivered_quantity = ordered_quantity
    end as is_in_full,

    case
        when order_status = 'delivered'
            then last_delivered_at <= promised_delivery_at
    end as is_on_time,

    case
        when order_status = 'delivered'
            then delivered_quantity = ordered_quantity
                and last_delivered_at <= promised_delivery_at
    end as is_otif

from fulfillment