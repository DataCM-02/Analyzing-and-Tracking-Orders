with source as (

    select *
    from {{ source("ecommerce", "orders") }}

),

renamed as (

    select
        order_id,
        upper(trim(order_number)) as order_number,
        customer_id,
        warehouse_id,
        lower(trim(order_status)) as order_status,
        lower(trim(service_level)) as service_level,
        promised_delivery_at,
        subtotal_amount,
        discount_amount,
        shipping_amount,
        tax_amount,
        total_amount,
        created_at,
        updated_at,
        cancelled_at,
        nullif(trim(cancellation_reason), '') as cancellation_reason
    from source

)

select *
from renamed