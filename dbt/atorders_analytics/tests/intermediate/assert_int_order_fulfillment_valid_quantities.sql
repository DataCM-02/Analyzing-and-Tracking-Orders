select
    order_id,
    order_status,
    ordered_quantity,
    shipped_quantity,
    delivered_quantity,
    unfulfilled_quantity,
    fulfillment_rate_percentage,
    is_in_full,
    is_on_time,
    is_otif
from {{ ref('int_order_fulfillment') }}
where
    ordered_quantity <= 0
    or shipped_quantity < 0
    or delivered_quantity < 0
    or delivered_quantity > shipped_quantity
    or shipped_quantity > ordered_quantity
    or unfulfilled_quantity < 0
    or fulfillment_rate_percentage < 0
    or fulfillment_rate_percentage > 100
    or (
        order_status = 'delivered'
        and (
            is_in_full is null
            or is_on_time is null
            or is_otif is null
        )
    )
    or (
        is_otif
        and not (is_in_full and is_on_time)
    )