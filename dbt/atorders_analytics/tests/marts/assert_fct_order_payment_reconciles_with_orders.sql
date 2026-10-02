select
    order_id,
    payment_attempt_count,
    declined_attempt_count,
    latest_payment_status,
    payment_approved_at,
    payment_amount_variance,
    has_approved_payment

from {{ ref('fct_order_payment') }}

where payment_amount_variance <> 0
   or declined_attempt_count > payment_attempt_count
   or (
       has_approved_payment
       and payment_approved_at is null
   )
   or (
       not has_approved_payment
       and payment_approved_at is not null
   )