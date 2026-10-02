with orders as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        order_status,
        service_level,
        promised_delivery_at,
        subtotal_amount,
        discount_amount,
        shipping_amount,
        tax_amount,
        total_amount,
        created_at,
        updated_at,
        cancelled_at,
        cancellation_reason

    from {{ ref('stg_ecommerce__orders') }}

)

select
    order_id,
    order_number,

    customer_id,
    warehouse_id,

    to_char(created_at, 'YYYYMMDD')::integer
        as order_date_key,

    to_char(promised_delivery_at, 'YYYYMMDD')::integer
        as promised_delivery_date_key,

    to_char(cancelled_at, 'YYYYMMDD')::integer
        as cancellation_date_key,

    order_status,
    service_level,

    subtotal_amount,
    discount_amount,

    subtotal_amount - discount_amount
        as net_merchandise_amount,

    shipping_amount,
    tax_amount,
    total_amount,

    created_at,
    updated_at,
    promised_delivery_at,
    cancelled_at,
    cancellation_reason,

    order_status = 'cancelled'
        as is_cancelled_order

from orders