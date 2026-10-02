with order_items as (

    select
        order_item_id,
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        order_status,
        service_level,
        order_created_at,
        product_id,
        quantity,
        sale_unit_price,
        catalog_unit_price,
        discount_amount,
        gross_line_amount,
        net_line_amount,
        discount_percentage,
        unit_price_variance,
        weight_kg,
        total_weight_kg

    from {{ ref('int_order_items_enriched') }}

)

select
    order_item_id,
    order_id,
    order_number,

    customer_id,
    warehouse_id,
    product_id,

    to_char(order_created_at, 'YYYYMMDD')::integer
        as order_date_key,

    order_status,
    service_level,

    quantity,
    sale_unit_price,
    catalog_unit_price,
    discount_amount,
    gross_line_amount,
    net_line_amount,
    discount_percentage,
    unit_price_variance,

    weight_kg as unit_weight_kg,
    total_weight_kg,

    order_status = 'cancelled'
        as is_cancelled_order

from order_items