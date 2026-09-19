with order_events as (

    select *
    from {{ ref('int_order_event_sequence') }}

),

order_milestones as (

    select
        order_id,

        min(event_time) as first_event_at,
        max(event_time) as last_event_at,
        count(*) as event_count,

        min(
            case
                when event_type = 'order_created' then event_time
            end
        ) as order_created_at,

        min(
            case
                when event_type = 'payment_approved' then event_time
            end
        ) as payment_approved_at,

        min(
            case
                when event_type = 'order_allocated' then event_time
            end
        ) as order_allocated_at,

        min(
            case
                when event_type = 'picking_started' then event_time
            end
        ) as picking_started_at,

        min(
            case
                when event_type = 'picking_completed' then event_time
            end
        ) as picking_completed_at,

        min(
            case
                when event_type = 'order_packed' then event_time
            end
        ) as order_packed_at,

        min(
            case
                when event_type = 'order_shipped' then event_time
            end
        ) as order_shipped_at,

        min(
            case
                when event_type = 'in_transit' then event_time
            end
        ) as in_transit_at,

        min(
            case
                when event_type = 'delivery_attempted' then event_time
            end
        ) as first_delivery_attempt_at,

        max(
            case
                when event_type = 'delivery_attempted' then event_time
            end
        ) as last_delivery_attempt_at,

        sum(
            case
                when event_type = 'delivery_attempted' then 1
                else 0
            end
        ) as delivery_attempt_count,

        min(
            case
                when event_type = 'order_delivered' then event_time
            end
        ) as order_delivered_at,

        min(
            case
                when event_type = 'order_cancelled' then event_time
            end
        ) as order_cancelled_at

    from order_events
    group by order_id

)

select *
from order_milestones