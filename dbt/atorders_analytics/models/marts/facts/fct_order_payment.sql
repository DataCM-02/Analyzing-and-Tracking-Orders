with payment_summary as (

    select
        order_id,
        payment_attempt_count,
        declined_attempt_count,
        first_payment_attempt_at,
        latest_payment_attempt_at,
        payment_approved_at,
        latest_payment_reference,
        latest_payment_status,
        latest_payment_method,
        latest_payment_amount,
        has_approved_payment

    from {{ ref('int_order_payment_summary') }}

),

orders as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        service_level,
        total_amount,
        created_at

    from {{ ref('stg_ecommerce__orders') }}

)

select
    p.order_id,
    o.order_number,

    o.customer_id,
    o.warehouse_id,

    to_char(o.created_at, 'YYYYMMDD')::integer
        as order_date_key,

    to_char(p.first_payment_attempt_at, 'YYYYMMDD')::integer
        as first_payment_attempt_date_key,

    to_char(p.latest_payment_attempt_at, 'YYYYMMDD')::integer
        as latest_payment_attempt_date_key,

    to_char(p.payment_approved_at, 'YYYYMMDD')::integer
        as payment_approved_date_key,

    o.service_level,

    p.payment_attempt_count,
    p.declined_attempt_count,

    p.first_payment_attempt_at,
    p.latest_payment_attempt_at,
    p.payment_approved_at,

    p.latest_payment_reference,
    p.latest_payment_status,
    p.latest_payment_method,
    p.latest_payment_amount,

    o.total_amount as order_total_amount,

    p.latest_payment_amount - o.total_amount
        as payment_amount_variance,

    round(
        (
            extract(
                epoch from (
                    p.payment_approved_at
                    - p.first_payment_attempt_at
                )
            ) / 3600.0
        )::numeric,
        2
    ) as payment_processing_hours,

    p.has_approved_payment,

    p.latest_payment_status = 'pending'
        as is_payment_pending,

    p.latest_payment_status = 'declined'
        as is_payment_declined

from payment_summary as p
inner join orders as o
    on p.order_id = o.order_id