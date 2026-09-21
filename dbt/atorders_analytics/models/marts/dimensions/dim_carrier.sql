with carriers as (

    select
        carrier_id,
        carrier_code,
        carrier_name,
        carrier_status

    from {{ ref('stg_ecommerce__carriers') }}

)

select
    carrier_id,
    carrier_code,
    carrier_name,
    carrier_status,

    carrier_status = 'active' as is_active_carrier

from carriers