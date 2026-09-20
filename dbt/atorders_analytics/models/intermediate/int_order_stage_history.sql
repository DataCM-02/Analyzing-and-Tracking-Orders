{{ config(materialized='view') }}

with analysis_clock as (

    select
        analysis_timestamp

    from {{ ref('int_analysis_clock') }}

),

orders as (

    select
        lifecycle.order_id,
        lifecycle.order_number,
        lifecycle.customer_id,
        lifecycle.warehouse_id,
        lifecycle.service_level,
        lifecycle.promised_delivery_at,
        lifecycle.current_stage as order_current_stage,

        lifecycle.order_created_at,
        payments.first_payment_attempt_at,

        coalesce(
            lifecycle.payment_approved_at,
            payments.payment_approved_at
        ) as payment_approved_at,

        lifecycle.order_packed_at,
        lifecycle.order_shipped_at,
        lifecycle.order_delivered_at,
        lifecycle.order_cancelled_at,

        lifecycle.is_late

    from {{ ref('int_order_lifecycle') }} as lifecycle

    left join {{ ref('int_order_payment_summary') }} as payments
        on lifecycle.order_id = payments.order_id

),

stage_boundaries as (

    select
        orders.*,
        stages.stage_sequence,
        stages.stage_code,
        stages.stage_name,
        stages.stage_started_at,
        stages.normal_stage_finished_at

    from orders

    cross join lateral (

        values
            (
                1,
                'entry',
                'Entrada',
                orders.order_created_at,
                orders.first_payment_attempt_at
            ),
            (
                2,
                'payment',
                'Pagamento',
                orders.first_payment_attempt_at,
                orders.payment_approved_at
            ),
            (
                3,
                'preparation',
                'Preparação',
                orders.payment_approved_at,
                orders.order_packed_at
            ),
            (
                4,
                'dispatch',
                'Expedição',
                orders.order_packed_at,
                orders.order_shipped_at
            ),
            (
                5,
                'transport',
                'Transporte',
                orders.order_shipped_at,
                orders.order_delivered_at
            ),
            (
                6,
                'delivery',
                'Entrega',
                orders.order_delivered_at,
                orders.order_delivered_at
            )

    ) as stages (
        stage_sequence,
        stage_code,
        stage_name,
        stage_started_at,
        normal_stage_finished_at
    )

),

started_stages as (

    select
        *,

        (
            order_cancelled_at is not null
            and order_cancelled_at >= stage_started_at
            and (
                normal_stage_finished_at is null
                or order_cancelled_at < normal_stage_finished_at
            )
        ) as is_cancelled_in_stage

    from stage_boundaries

    where stage_started_at is not null

      and (
          order_cancelled_at is null
          or stage_started_at <= order_cancelled_at
      )

),

resolved_stages as (

    select
        *,

        case
            when is_cancelled_in_stage
                then order_cancelled_at
            else normal_stage_finished_at
        end as stage_finished_at

    from started_stages

),

final as (

    select
        resolved_stages.order_id,
        resolved_stages.order_number,
        resolved_stages.customer_id,
        resolved_stages.warehouse_id,
        resolved_stages.service_level,
        resolved_stages.promised_delivery_at,
        resolved_stages.order_current_stage,

        resolved_stages.stage_sequence,
        resolved_stages.stage_code,
        resolved_stages.stage_name,
        resolved_stages.stage_started_at,
        resolved_stages.stage_finished_at,

        case
            when resolved_stages.stage_finished_at is not null
                then round(
                    (
                        extract(
                            epoch from (
                                resolved_stages.stage_finished_at
                                - resolved_stages.stage_started_at
                            )
                        ) / 3600.0
                    )::numeric,
                    2
                )
        end as stage_duration_hours,

        case
            when resolved_stages.stage_finished_at is null
                then round(
                    (
                        extract(
                            epoch from (
                                analysis_clock.analysis_timestamp
                                - resolved_stages.stage_started_at
                            )
                        ) / 3600.0
                    )::numeric,
                    2
                )
        end as stage_age_hours,

        case
            when resolved_stages.is_cancelled_in_stage
                then 'cancelled'

            when resolved_stages.stage_finished_at is null
                then 'current'

            else 'completed'
        end as stage_status,

        (
            resolved_stages.stage_finished_at is not null
            and not resolved_stages.is_cancelled_in_stage
        ) as is_completed_stage,

        (
            resolved_stages.stage_finished_at is null
            and not resolved_stages.is_cancelled_in_stage
        ) as is_current_stage,

        resolved_stages.is_cancelled_in_stage,
        resolved_stages.is_late,
        resolved_stages.order_delivered_at,
        resolved_stages.order_cancelled_at

    from resolved_stages

    cross join analysis_clock

)

select *
from final