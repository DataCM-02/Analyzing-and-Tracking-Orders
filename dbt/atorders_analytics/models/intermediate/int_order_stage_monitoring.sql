{{ config(materialized='view') }}

with analysis_clock as (

    select
        analysis_timestamp

    from {{ ref('int_analysis_clock') }}

),

current_stages as (

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
        stage_age_hours,

        is_late

    from {{ ref('int_order_stage_history') }}

    where is_current_stage

),

stages_with_benchmarks as (

    select
        current_stages.*,

        analysis_clock.analysis_timestamp,

        benchmarks.completed_stage_count,
        benchmarks.average_duration_hours,
        benchmarks.median_duration_hours,
        benchmarks.p75_duration_hours,
        benchmarks.p90_duration_hours,
        benchmarks.critical_threshold_hours,

        round(
            current_stages.stage_age_hours
            - benchmarks.average_duration_hours,
            2
        ) as stage_variance_hours,

        round(
            current_stages.stage_age_hours
            / nullif(
                benchmarks.average_duration_hours,
                0
            ),
            2
        ) as stage_age_ratio,

        round(
            (
                extract(
                    epoch from (
                        current_stages.promised_delivery_at
                        - analysis_clock.analysis_timestamp
                    )
                ) / 3600.0
            )::numeric,
            2
        ) as hours_until_promised_delivery

    from current_stages

    inner join {{ ref('int_stage_benchmarks') }} as benchmarks
        on current_stages.stage_code = benchmarks.stage_code
        and current_stages.service_level = benchmarks.service_level

    cross join analysis_clock

),

evaluated_stages as (

    select
        *,

        stage_age_hours > average_duration_hours
            as is_above_average,

        stage_age_hours > critical_threshold_hours
            as is_above_critical_threshold,

        case
            when is_late is true
                then 'red'

            when stage_age_hours > critical_threshold_hours
                then 'red'

            when stage_age_hours > average_duration_hours
                then 'yellow'

            else 'green'
        end as stage_signal,

        case
            when is_late is true
                then 'promised_delivery_overdue'

            when stage_age_hours > critical_threshold_hours
                then 'stage_above_critical_threshold'

            when stage_age_hours > average_duration_hours
                then 'stage_above_average'

            else 'within_average'
        end as signal_reason

    from stages_with_benchmarks

),

final as (

    select
        *,

        case stage_signal
            when 'red' then 3
            when 'yellow' then 2
            when 'green' then 1
        end as signal_priority

    from evaluated_stages

)

select *
from final