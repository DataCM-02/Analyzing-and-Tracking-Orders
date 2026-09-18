with source as (

    select *
    from {{ source("ecommerce", "warehouses") }}

),

renamed as (

    select
        warehouse_id,
        upper(trim(warehouse_code)) as warehouse_code,
        trim(warehouse_name) as warehouse_name,
        trim(city) as city,
        upper(trim(state)) as state_code,
        lower(trim(region)) as region,
        lower(trim(status)) as warehouse_status
    from source

)

select *
from renamed