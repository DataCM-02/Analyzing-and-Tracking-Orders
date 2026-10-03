with control_tower as (

    select
        order_id,
        flow_status,
        stage_signal,
        active_order_count,
        cancelled_order_count,
        delivered_order_count

    from {{ ref('mart_control_tower') }}

),

orders as (

    select
        order_id

    from {{ ref('fct_order') }}

),

coverage_issues as (

    select
        coalesce(
            control_tower.order_id,
            orders.order_id
        ) as order_id,
        'order_coverage' as issue_type

    from control_tower

    full outer join orders
        on control_tower.order_id = orders.order_id

    where control_tower.order_id is null
       or orders.order_id is null

),

classification_issues as (

    select
        order_id,
        'order_classification' as issue_type

    from control_tower

    where (
        active_order_count
        + cancelled_order_count
        + delivered_order_count
    ) <> 1

       or (
            flow_status = 'active'
            and active_order_count <> 1
       )

       or (
            flow_status = 'cancelled'
            and cancelled_order_count <> 1
       )

       or (
            flow_status = 'delivered'
            and delivered_order_count <> 1
       )

       or (
            flow_status = 'active'
            and stage_signal is null
       )

)

select
    order_id,
    issue_type

from coverage_issues

union all

select
    order_id,
    issue_type

from classification_issues