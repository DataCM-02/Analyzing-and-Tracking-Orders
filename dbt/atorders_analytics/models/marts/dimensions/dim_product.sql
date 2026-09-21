with products as (

    select
        product_id,
        sku,
        product_name,
        product_category,
        unit_price,
        weight_kg,
        product_status,
        created_at,
        updated_at

    from {{ ref('stg_ecommerce__products') }}

)

select
    product_id,
    sku,
    product_name,
    product_category,
    unit_price,
    weight_kg,
    product_status,

    product_status = 'active' as is_active_product,

    created_at,
    updated_at

from products