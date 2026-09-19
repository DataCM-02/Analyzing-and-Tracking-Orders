with order_items as (

    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_amount
    from {{ ref('stg_ecommerce__order_items') }}

),

products as (

    select
        product_id,
        sku,
        product_name,
        product_category,
        unit_price,
        weight_kg,
        product_status
    from {{ ref('stg_ecommerce__products') }}

),

orders as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        order_status,
        service_level,
        created_at
    from {{ ref('stg_ecommerce__orders') }}

)

select
    oi.order_item_id,
    oi.order_id,
    o.order_number,
    o.customer_id,
    o.warehouse_id,
    o.order_status,
    o.service_level,
    o.created_at as order_created_at,

    oi.product_id,
    p.sku,
    p.product_name,
    p.product_category,
    p.product_status,

    oi.quantity,
    oi.unit_price as sale_unit_price,
    p.unit_price as catalog_unit_price,
    oi.discount_amount,

    round(
        (oi.quantity * oi.unit_price)::numeric,
        2
    ) as gross_line_amount,

    round(
        (
            oi.quantity * oi.unit_price
            - oi.discount_amount
        )::numeric,
        2
    ) as net_line_amount,

    round(
        (
            100.0
            * oi.discount_amount
            / nullif(oi.quantity * oi.unit_price, 0)
        )::numeric,
        2
    ) as discount_percentage,

    round(
        (oi.unit_price - p.unit_price)::numeric,
        2
    ) as unit_price_variance,

    p.weight_kg,

    round(
        (oi.quantity * p.weight_kg)::numeric,
        3
    ) as total_weight_kg

from order_items as oi
left join products as p
    on oi.product_id = p.product_id
left join orders as o
    on oi.order_id = o.order_id