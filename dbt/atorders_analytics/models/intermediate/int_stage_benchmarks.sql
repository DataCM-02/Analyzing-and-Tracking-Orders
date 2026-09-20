{{ config(materialized='view') }}

with completed_stages as (

    select
        stage_sequence,
        stage_code,
        stage_name,
        service_level,
        stage_duration_hours

    from {{ ref('int_order_stage_history') }}

    where is_completed_stage
      and stage_code <> 'delivery'
      and stage_duration_hours is not null

),

benchmarks as (

    select
        stage_sequence,
        stage_code,
        stage_name,
        service_level,

        count(*) as completed_stage_count,

        round(
            avg(stage_duration_hours),
            2
        ) as average_duration_hours,

        round(
            (
                percentile_cont(0.50)
                within group (
                    order by stage_duration_hours
                )
            )::numeric,
            2
        ) as median_duration_hours,

        round(
            (
                percentile_cont(0.75)
                within group (
                    order by stage_duration_hours
                )
            )::numeric,
            2
        ) as p75_duration_hours,

        round(
            (
                percentile_cont(0.90)
                within group (
                    order by stage_duration_hours
                )
            )::numeric,
            2
        ) as p90_duration_hours

    from completed_stages

    group by
        stage_sequence,
        stage_code,
        stage_name,
        service_level

),

final as (

    select
        *,

        round(
            average_duration_hours * 1.25,
            2
        ) as critical_threshold_hours

    from benchmarks

)

select *
from final