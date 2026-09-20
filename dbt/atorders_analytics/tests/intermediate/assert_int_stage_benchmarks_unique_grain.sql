select
    stage_code,
    service_level,
    count(*) as row_count

from {{ ref('int_stage_benchmarks') }}

group by
    stage_code,
    service_level

having count(*) > 1