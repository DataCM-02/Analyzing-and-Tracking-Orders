with customers as (

    select
        customer_id,
        customer_code,
        customer_name,
        customer_segment,
        customer_status,
        city,
        state_code,
        region,
        created_at,
        updated_at

    from {{ ref('stg_ecommerce__customers') }}

)

select
    customer_id,
    customer_code,
    customer_name,
    customer_segment,
    customer_status,

    customer_status = 'active' as is_active_customer,

    city,
    state_code,
    region,
    created_at,
    updated_at

from customers