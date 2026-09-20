{{ config(materialized='view') }}

with analysis_clock as (

    select
        analysis_timestamp

    from {{ ref('int_analysis_clock') }}

),

orders as (

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
        orders.order_id,
        orders.order_number,
        orders.customer_id,
        orders.warehouse_id,
        orders.order_status as current_stage,
        orders.service_level,
        orders.promised_delivery_at,

        coalesce(
            milestones.order_created_at,
            orders.created_at
        ) as order_created_at,

        milestones.payment_approved_at,
        milestones.order_allocated_at,
        milestones.picking_started_at,
        milestones.picking_completed_at,
        milestones.order_packed_at,
        milestones.order_shipped_at,
        milestones.in_transit_at,
        milestones.first_delivery_attempt_at,
        milestones.last_delivery_attempt_at,
        milestones.delivery_attempt_count,
        milestones.order_delivered_at,

        coalesce(
            milestones.order_cancelled_at,
            orders.cancelled_at
        ) as order_cancelled_at,

        milestones.first_event_at,
        milestones.last_event_at,
        milestones.event_count

    from orders

    left join milestones
        on orders.order_id = milestones.order_id

),

with_stage_start as (

    select
        *,

        coalesce(
            case current_stage
                when 'created'
                    then order_created_at

                when 'payment_pending'
                    then order_created_at

                when 'paid'
                    then payment_approved_at

                when 'allocated'
                    then order_allocated_at

                when 'picking'
                    then picking_started_at

                when 'picked'
                    then picking_completed_at

                when 'packed'
                    then order_packed_at

                when 'shipped'
                    then order_shipped_at

                when 'in_transit'
                    then coalesce(
                        last_delivery_attempt_at,
                        in_transit_at
                    )

                when 'delivered'
                    then order_delivered_at

                when 'cancelled'
                    then order_cancelled_at
            end,

            last_event_at,
            order_created_at
        ) as current_stage_started_at

    from order_journey

),

final as (

    select
        with_stage_start.*,

        round(
            (
                extract(
                    epoch from (
                        payment_approved_at
                        - order_created_at
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as payment_approval_hours,

        round(
            (
                extract(
                    epoch from (
                        order_allocated_at
                        - payment_approved_at
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as allocation_wait_hours,

        round(
            (
                extract(
                    epoch from (
                        picking_completed_at
                        - picking_started_at
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as picking_hours,

        round(
            (
                extract(
                    epoch from (
                        order_packed_at
                        - picking_completed_at
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as packing_hours,

        round(
            (
                extract(
                    epoch from (
                        order_shipped_at
                        - order_packed_at
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as dispatch_hours,

        round(
            (
                extract(
                    epoch from (
                        order_delivered_at
                        - in_transit_at
                    )
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
                            analysis_clock.analysis_timestamp
                        ) - order_created_at
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as total_cycle_hours,

        case
            when current_stage in ('delivered', 'cancelled')
                then null

            else round(
                (
                    extract(
                        epoch from (
                            analysis_clock.analysis_timestamp
                            - current_stage_started_at
                        )
                    ) / 3600.0
                )::numeric,
                2
            )
        end as current_stage_age_hours,

        case
            when current_stage = 'cancelled'
                then null

            when order_delivered_at is not null
                then order_delivered_at > promised_delivery_at

            else
                analysis_clock.analysis_timestamp
                > promised_delivery_at
        end as is_late,

        current_stage = 'delivered' as is_completed,
        current_stage = 'cancelled' as is_cancelled

    from with_stage_start

    cross join analysis_clock

)

select *
from final