with executive_flow as (

    select
        stage_code,
        entered_order_count,
        completed_order_count,
        current_order_count,
        cancelled_order_count,
        green_order_count,
        yellow_order_count,
        red_order_count,
        stage_signal

    from {{ ref('mart_executive_order_flow') }}

),

control_tower_totals as (

    select
        sum(active_order_count) as active_order_count,
        sum(cancelled_order_count) as cancelled_order_count

    from {{ ref('mart_control_tower') }}

),

executive_flow_totals as (

    select
        sum(current_order_count) as active_order_count,
        sum(cancelled_order_count) as cancelled_order_count,
        sum(
            green_order_count
            + yellow_order_count
            + red_order_count
        ) as signalled_order_count

    from executive_flow

),

stage_balance_issues as (

    select
        stage_code,
        'stage_balance' as issue_type

    from executive_flow

    where entered_order_count <> (
        completed_order_count
        + current_order_count
        + cancelled_order_count
    )

),

stage_signal_issues as (

    select
        stage_code,
        'stage_signal' as issue_type

    from executive_flow

    where (
        red_order_count > 0
        and stage_signal <> 'red'
    )

       or (
            red_order_count = 0
            and yellow_order_count > 0
            and stage_signal <> 'yellow'
       )

       or (
            red_order_count = 0
            and yellow_order_count = 0
            and current_order_count > 0
            and stage_signal <> 'green'
       )

       or (
            current_order_count = 0
            and stage_signal <> 'neutral'
       )

),

global_total_issues as (

    select
        cast(null as text) as stage_code,
        'global_totals' as issue_type

    from executive_flow_totals

    cross join control_tower_totals

    where executive_flow_totals.active_order_count
        <> control_tower_totals.active_order_count

       or executive_flow_totals.cancelled_order_count
        <> control_tower_totals.cancelled_order_count

       or executive_flow_totals.signalled_order_count
        <> control_tower_totals.active_order_count

)

select
    stage_code,
    issue_type
from stage_balance_issues

union all

select
    stage_code,
    issue_type
from stage_signal_issues

union all

select
    stage_code,
    issue_type
from global_total_issues