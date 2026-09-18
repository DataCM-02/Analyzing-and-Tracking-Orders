with source as (

    select *
    from {{ source("ecommerce", "payments") }}

),

renamed as (

    select
        payment_id,
        upper(trim(payment_reference)) as payment_reference,
        order_id,
        attempt_number,
        lower(trim(payment_status)) as payment_status,
        lower(trim(payment_method)) as payment_method,
        amount,
        created_at,
        approved_at
    from source

)

select *
from renamed