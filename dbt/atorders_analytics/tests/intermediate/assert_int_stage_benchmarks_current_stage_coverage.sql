with current_stage_groups as (

    select distinct
        stage_code,
        service_level

    from {{ ref('int_order_stage_history') }}

    where is_current_stage

),

missing_benchmarks as (

    select
        current_stage_groups.stage_code,
        current_stage_groups.service_level

    from current_stage_groups

    left join {{ ref('int_stage_benchmarks') }} as benchmarks
        on current_stage_groups.stage_code = benchmarks.stage_code
        and current_stage_groups.service_level = benchmarks.service_level

    where benchmarks.stage_code is null

)

select *
from missing_benchmarks