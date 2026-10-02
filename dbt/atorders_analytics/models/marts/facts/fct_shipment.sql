with shipments as (

    select
        shipment_id,
        shipment_number,
        order_id,
        carrier_id,
        shipment_status,
        delivery_attempts,
        shipped_at,
        in_transit_at,
        delivered_at

    from {{ ref('stg_ecommerce__shipments') }}

),

shipment_items as (

    select
        shipment_id,
        count(*) as shipment_item_count,
        sum(quantity_shipped) as quantity_shipped,
        sum(quantity_delivered) as quantity_delivered

    from {{ ref('stg_ecommerce__shipment_items') }}

    group by shipment_id

),

orders as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        promised_delivery_at,
        created_at as order_created_at

    from {{ ref('stg_ecommerce__orders') }}

)

select
    s.shipment_id,
    s.shipment_number,

    s.order_id,
    o.order_number,

    o.customer_id,
    o.warehouse_id,
    s.carrier_id,

    to_char(o.order_created_at, 'YYYYMMDD')::integer
        as order_date_key,

    to_char(s.shipped_at, 'YYYYMMDD')::integer
        as shipped_date_key,

    to_char(s.in_transit_at, 'YYYYMMDD')::integer
        as in_transit_date_key,

    to_char(s.delivered_at, 'YYYYMMDD')::integer
        as delivered_date_key,

    to_char(o.promised_delivery_at, 'YYYYMMDD')::integer
        as promised_delivery_date_key,

    s.shipment_status,
    s.delivery_attempts,

    si.shipment_item_count,
    si.quantity_shipped,
    si.quantity_delivered,

    si.quantity_shipped - si.quantity_delivered
        as undelivered_quantity,

    s.shipped_at,
    s.in_transit_at,
    s.delivered_at,
    o.promised_delivery_at,

    round(
        (
            extract(
                epoch from (
                    s.delivered_at - s.shipped_at
                )
            ) / 3600.0
        )::numeric,
        2
    ) as delivery_cycle_hours,

    s.shipment_status = 'delivered'
        as is_delivered,

    case
        when s.shipment_status = 'delivered'
            then s.delivered_at <= o.promised_delivery_at
        else null
    end as is_on_time_delivery,

    case
        when s.shipment_status = 'delivered'
            then si.quantity_delivered = si.quantity_shipped
        else null
    end as is_in_full_delivery,

    case
        when s.shipment_status = 'delivered'
            then si.quantity_delivered < si.quantity_shipped
        else null
    end as is_partial_delivery,

    case
        when s.shipment_status = 'delivered'
            then
                s.delivered_at <= o.promised_delivery_at
                and si.quantity_delivered = si.quantity_shipped
        else null
    end as is_otif

from shipments as s
inner join orders as o
    on s.order_id = o.order_id
left join shipment_items as si
    on s.shipment_id = si.shipment_id