with source as (

    select *
    from {{ source("ecommerce", "shipments") }}

),

renamed as (

    select
        shipment_id,
        upper(trim(shipment_number)) as shipment_number,
        order_id,
        carrier_id,
        lower(trim(shipment_status)) as shipment_status,
        delivery_attempts,
        shipped_at,
        in_transit_at,
        delivered_at
    from source

)

select *
from renamed