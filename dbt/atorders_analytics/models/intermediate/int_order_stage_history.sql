{{ config(materialized='view') }}

with orders as (

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
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        service_level,
        promised_delivery_at,
        order_current_stage,

        stage_sequence,
        stage_code,
        stage_name,
        stage_started_at,
        stage_finished_at,

        case
            when stage_finished_at is not null
                then round(
                    (
                        extract(
                            epoch from (
                                stage_finished_at - stage_started_at
                            )
                        ) / 3600.0
                    )::numeric,
                    2
                )
        end as stage_duration_hours,

        case
            when stage_finished_at is null
                then round(
                    (
                        extract(
                            epoch from (
                                current_timestamp - stage_started_at
                            )
                        ) / 3600.0
                    )::numeric,
                    2
                )
        end as stage_age_hours,

        case
            when is_cancelled_in_stage
                then 'cancelled'
            when stage_finished_at is null
                then 'current'
            else 'completed'
        end as stage_status,

        (
            stage_finished_at is not null
            and not is_cancelled_in_stage
        ) as is_completed_stage,

        (
            stage_finished_at is null
            and not is_cancelled_in_stage
        ) as is_current_stage,

        is_cancelled_in_stage,
        is_late,

        order_delivered_at,
        order_cancelled_at

    from resolved_stages

)

select *
from final