with source as (

    select *
    from {{ source("ecommerce", "products") }}

),

renamed as (

    select
        product_id,
        upper(trim(sku)) as sku,
        trim(product_name) as product_name,
        lower(trim(category)) as product_category,
        unit_price,
        weight_kg,
        lower(trim(status)) as product_status,
        created_at,
        updated_at
    from source

)

select *
from renamed