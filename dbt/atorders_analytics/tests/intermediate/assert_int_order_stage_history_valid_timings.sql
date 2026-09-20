select *

from {{ ref('int_order_stage_history') }}

where
    stage_finished_at < stage_started_at

    or stage_duration_hours < 0

    or stage_age_hours < 0

    or (
        stage_status = 'current'
        and (
            stage_finished_at is not null
            or stage_duration_hours is not null
            or stage_age_hours is null
        )
    )

    or (
        stage_status in ('completed', 'cancelled')
        and (
            stage_finished_at is null
            or stage_duration_hours is null
            or stage_age_hours is not null
        )
    )