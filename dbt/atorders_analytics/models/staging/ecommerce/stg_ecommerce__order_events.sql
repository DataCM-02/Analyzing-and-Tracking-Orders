with source as (

    select *
    from {{ source("ecommerce", "order_events") }}

),

renamed as (

    select
        event_record_id,
        event_id,
        order_id,
        lower(trim(event_type)) as event_type,
        event_time,
        received_at,
        lower(trim(source_system)) as source_system,
        event_payload
    from source

)

select *
from renamed