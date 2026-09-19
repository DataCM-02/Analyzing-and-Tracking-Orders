select
    order_item_id,
    order_id,
    product_id,
    quantity,
    sale_unit_price,
    discount_amount,
    gross_line_amount,
    net_line_amount,
    weight_kg,
    total_weight_kg
from {{ ref('int_order_items_enriched') }}
where
    quantity <= 0
    or sale_unit_price < 0
    or discount_amount < 0
    or discount_amount > gross_line_amount
    or gross_line_amount <> round(
        (quantity * sale_unit_price)::numeric,
        2
    )
    or net_line_amount <> gross_line_amount - discount_amount
    or weight_kg <= 0
    or total_weight_kg <= 0