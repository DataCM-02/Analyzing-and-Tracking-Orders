with warehouses as (

    select
        warehouse_id,
        warehouse_code,
        warehouse_name,
        city,
        state_code,
        region,
        warehouse_status

    from {{ ref('stg_ecommerce__warehouses') }}

)

select
    warehouse_id,
    warehouse_code,
    warehouse_name,
    city,
    state_code,
    region,
    warehouse_status,

    warehouse_status = 'active' as is_active_warehouse

from warehouses