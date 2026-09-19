with payments as (

    select
        payment_id,
        payment_reference,
        order_id,
        attempt_number,
        payment_status,
        payment_method,
        amount,
        created_at,
        approved_at
    from {{ ref('stg_ecommerce__payments') }}

),

ranked_payments as (

    select
        *,
        row_number() over (
            partition by order_id
            order by
                attempt_number desc,
                created_at desc,
                payment_id desc
        ) as payment_recency_rank
    from payments

)

select
    order_id,

    count(*) as payment_attempt_count,

    sum(
        case
            when payment_status = 'declined' then 1
            else 0
        end
    ) as declined_attempt_count,

    min(created_at) as first_payment_attempt_at,
    max(created_at) as latest_payment_attempt_at,

    min(
        case
            when payment_status = 'approved' then approved_at
        end
    ) as payment_approved_at,

    max(
        case
            when payment_recency_rank = 1 then payment_reference
        end
    ) as latest_payment_reference,

    max(
        case
            when payment_recency_rank = 1 then payment_status
        end
    ) as latest_payment_status,

    max(
        case
            when payment_recency_rank = 1 then payment_method
        end
    ) as latest_payment_method,

    max(
        case
            when payment_recency_rank = 1 then amount
        end
    ) as latest_payment_amount,

    sum(
        case
            when payment_status = 'approved' then 1
            else 0
        end
    ) > 0 as has_approved_payment

from ranked_payments
group by order_id