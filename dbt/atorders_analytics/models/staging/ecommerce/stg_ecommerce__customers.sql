with source as (

    select *
    from {{ source("ecommerce", "customers") }}

),

renamed as (

    select
        customer_id,
        upper(trim(customer_code)) as customer_code,
        trim(company_name) as customer_name,
        lower(trim(segment)) as customer_segment,
        lower(trim(status)) as customer_status,
        trim(city) as city,
        upper(trim(state)) as state_code,
        lower(trim(region)) as region,
        created_at,
        updated_at
    from source

)

select *
from renamed