with duplicated_stages as (

    select
        order_id,
        stage_sequence,
        count(*) as row_count

    from {{ ref('int_order_stage_history') }}

    group by
        order_id,
        stage_sequence

    having count(*) > 1

)

select *
from duplicated_stages