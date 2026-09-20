with lifecycle as (

    select
        order_id,
        is_completed,
        is_cancelled

    from {{ ref('int_order_lifecycle') }}

),

stage_summary as (

    select
        order_id,

        count(*) filter (
            where is_current_stage
        ) as current_stage_count,

        count(*) filter (
            where is_cancelled_in_stage
        ) as cancellation_stage_count,

        count(*) filter (
            where stage_code = 'delivery'
              and is_completed_stage
        ) as delivery_stage_count

    from {{ ref('int_order_stage_history') }}

    group by order_id

),

validation as (

    select
        lifecycle.order_id,
        lifecycle.is_completed,
        lifecycle.is_cancelled,

        coalesce(stage_summary.current_stage_count, 0)
            as current_stage_count,

        coalesce(stage_summary.cancellation_stage_count, 0)
            as cancellation_stage_count,

        coalesce(stage_summary.delivery_stage_count, 0)
            as delivery_stage_count

    from lifecycle

    left join stage_summary
        on lifecycle.order_id = stage_summary.order_id

)

select *

from validation

where
    (
        is_cancelled
        and (
            cancellation_stage_count <> 1
            or current_stage_count <> 0
            or delivery_stage_count <> 0
        )
    )

    or (
        is_completed
        and (
            delivery_stage_count <> 1
            or current_stage_count <> 0
            or cancellation_stage_count <> 0
        )
    )

    or (
        not is_completed
        and not is_cancelled
        and (
            current_stage_count <> 1
            or cancellation_stage_count <> 0
            or delivery_stage_count <> 0
        )
    )