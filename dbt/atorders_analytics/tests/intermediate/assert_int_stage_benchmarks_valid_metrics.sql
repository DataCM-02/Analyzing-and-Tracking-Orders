select *

from {{ ref('int_stage_benchmarks') }}

where
    completed_stage_count <= 0

    or average_duration_hours < 0
    or median_duration_hours < 0
    or p75_duration_hours < 0
    or p90_duration_hours < 0
    or critical_threshold_hours < 0

    or median_duration_hours > p75_duration_hours
    or p75_duration_hours > p90_duration_hours

    or critical_threshold_hours < average_duration_hours

    or abs(
        critical_threshold_hours
        - round(average_duration_hours * 1.25, 2)
    ) > 0.01