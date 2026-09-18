with source as (

    select *
    from {{ source("ecommerce", "carriers") }}

),

renamed as (

    select
        carrier_id,
        upper(trim(carrier_code)) as carrier_code,
        trim(carrier_name) as carrier_name,
        lower(trim(status)) as carrier_status
    from source

)

select *
from renamed