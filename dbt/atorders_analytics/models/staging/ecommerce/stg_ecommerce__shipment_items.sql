with source as (

    select *
    from {{ source("ecommerce", "shipment_items") }}

),

renamed as (

    select
        shipment_item_id,
        shipment_id,
        order_item_id,
        quantity_shipped,
        quantity_delivered
    from source

)

select *
from renamed