with service_levels as (

    select distinct
        service_level

    from {{ ref('stg_ecommerce__orders') }}

)

select
    service_level,

    case service_level
        when 'standard' then 'Padrão'
        when 'express' then 'Expresso'
        when 'priority' then 'Prioritário'
        else service_level
    end as service_level_name,

    case service_level
        when 'standard' then 1
        when 'express' then 2
        when 'priority' then 3
        else 99
    end as service_level_sort_order

from service_levels