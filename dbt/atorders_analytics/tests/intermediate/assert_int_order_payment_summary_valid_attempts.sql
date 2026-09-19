select
    order_id,
    payment_attempt_count,
    declined_attempt_count,
    payment_approved_at,
    latest_payment_status,
    latest_payment_amount,
    has_approved_payment
from {{ ref('int_order_payment_summary') }}
where
    payment_attempt_count <= 0
    or declined_attempt_count < 0
    or declined_attempt_count > payment_attempt_count
    or latest_payment_amount <= 0
    or (
        has_approved_payment
        and payment_approved_at is null
    )
    or (
        not has_approved_payment
        and payment_approved_at is not null
    )