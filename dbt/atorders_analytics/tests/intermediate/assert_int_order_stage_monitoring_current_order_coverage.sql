with current_orders as (

    select
        order_id

    from {{ ref('int_order_stage_history') }}

    where is_current_stage

),

monitored_orders as (

    select
        order_id

    from {{ ref('int_order_stage_monitoring') }}

)

select
    current_orders.order_id as expected_order_id,
    monitored_orders.order_id as monitored_order_id

from current_orders

full outer join monitored_orders
    on current_orders.order_id = monitored_orders.order_id

where current_orders.order_id is null
   or monitored_orders.order_id is null