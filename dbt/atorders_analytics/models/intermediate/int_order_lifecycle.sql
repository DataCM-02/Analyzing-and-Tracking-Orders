with orders as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        order_status,
        service_level,
        promised_delivery_at,
        created_at,
        cancelled_at
    from {{ ref('stg_ecommerce__orders') }}

),

milestones as (

    select *
    from {{ ref('int_order_milestones') }}

),

order_journey as (

    select
        o.order_id,
        o.order_number,
        o.customer_id,
        o.warehouse_id,
        o.order_status as current_stage,
        o.service_level,
        o.promised_delivery_at,

        coalesce(m.order_created_at, o.created_at) as order_created_at,
        m.payment_approved_at,
        m.order_allocated_at,
        m.picking_started_at,
        m.picking_completed_at,
        m.order_packed_at,
        m.order_shipped_at,
        m.in_transit_at,
        m.first_delivery_attempt_at,
        m.last_delivery_attempt_at,
        m.delivery_attempt_count,
        m.order_delivered_at,
        coalesce(m.order_cancelled_at, o.cancelled_at) as order_cancelled_at,

        m.first_event_at,
        m.last_event_at,
        m.event_count

    from orders as o
    left join milestones as m
        on o.order_id = m.order_id

),

with_stage_start as (

    select
        *,

        coalesce(
            case current_stage
                when 'created' then order_created_at
                when 'payment_pending' then order_created_at
                when 'paid' then payment_approved_at
                when 'allocated' then order_allocated_at
                when 'picking' then picking_started_at
                when 'picked' then picking_completed_at
                when 'packed' then order_packed_at
                when 'shipped' then order_shipped_at
                when 'in_transit' then coalesce(
                    last_delivery_attempt_at,
                    in_transit_at
                )
                when 'delivered' then order_delivered_at
                when 'cancelled' then order_cancelled_at
            end,
            last_event_at,
            order_created_at
        ) as current_stage_started_at

    from order_journey

)

select
    *,

    round(
        (
            extract(
                epoch from payment_approved_at - order_created_at
            ) / 3600.0
        )::numeric,
        2
    ) as payment_approval_hours,

    round(
        (
            extract(
                epoch from order_allocated_at - payment_approved_at
            ) / 3600.0
        )::numeric,
        2
    ) as allocation_wait_hours,

    round(
        (
            extract(
                epoch from picking_completed_at - picking_started_at
            ) / 3600.0
        )::numeric,
        2
    ) as picking_hours,

    round(
        (
            extract(
                epoch from order_packed_at - picking_completed_at
            ) / 3600.0
        )::numeric,
        2
    ) as packing_hours,

    round(
        (
            extract(
                epoch from order_shipped_at - order_packed_at
            ) / 3600.0
        )::numeric,
        2
    ) as dispatch_hours,

    round(
        (
            extract(
                epoch from order_delivered_at - in_transit_at
            ) / 3600.0
        )::numeric,
        2
    ) as transit_hours,

    round(
        (
            extract(
                epoch from (
                    coalesce(
                        order_delivered_at,
                        order_cancelled_at,
                        current_timestamp
                    ) - order_created_at
                )
            ) / 3600.0
        )::numeric,
        2
    ) as total_cycle_hours,

    case
        when current_stage in ('delivered', 'cancelled') then null
        else round(
            (
                extract(
                    epoch from current_timestamp - current_stage_started_at
                ) / 3600.0
            )::numeric,
            2
        )
    end as current_stage_age_hours,

    case
        when current_stage = 'cancelled' then null
        when order_delivered_at is not null
            then order_delivered_at > promised_delivery_at
        else current_timestamp > promised_delivery_at
    end as is_late,

    current_stage = 'delivered' as is_completed,
    current_stage = 'cancelled' as is_cancelled

from with_stage_start