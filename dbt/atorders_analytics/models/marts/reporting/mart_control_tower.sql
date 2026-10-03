{{ config(materialized='table') }}

with order_stage_snapshot as (

    select
        order_id,
        stage_sequence,
        stage_code,
        stage_name,
        stage_started_at,
        stage_finished_at,
        stage_duration_hours,
        stage_age_hours,
        stage_status,
        is_completed_stage,
        is_current_stage,
        is_cancelled_in_stage,
        is_late

    from {{ ref('fct_order_stage') }}

    where is_current_stage
       or is_cancelled_in_stage
       or (
            stage_code = 'delivery'
            and is_completed_stage
       )

),

stage_monitoring as (

    select
        order_id,
        analysis_timestamp,
        stage_age_hours,
        completed_stage_count,
        average_duration_hours,
        median_duration_hours,
        p75_duration_hours,
        p90_duration_hours,
        critical_threshold_hours,
        stage_variance_hours,
        stage_age_ratio,
        hours_until_promised_delivery,
        is_above_average,
        is_above_critical_threshold,
        stage_signal,
        signal_reason,
        signal_priority

    from {{ ref('int_order_stage_monitoring') }}

),

orders as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        order_status,
        service_level,
        subtotal_amount,
        discount_amount,
        net_merchandise_amount,
        shipping_amount,
        tax_amount,
        total_amount,
        created_at,
        updated_at,
        promised_delivery_at,
        cancelled_at,
        cancellation_reason,
        is_cancelled_order

    from {{ ref('fct_order') }}

),

customers as (

    select
        customer_id,
        customer_code,
        customer_name,
        customer_segment,
        customer_status,
        city,
        state_code,
        region

    from {{ ref('dim_customer') }}

),

warehouses as (

    select
        warehouse_id,
        warehouse_code,
        warehouse_name,
        city,
        state_code,
        region,
        warehouse_status

    from {{ ref('dim_warehouse') }}

)

select
    orders.order_id,
    orders.order_number,

    orders.customer_id,
    customers.customer_code,
    customers.customer_name,
    customers.customer_segment,
    customers.customer_status,
    customers.city as customer_city,
    customers.state_code as customer_state_code,
    customers.region as customer_region,

    orders.warehouse_id,
    warehouses.warehouse_code,
    warehouses.warehouse_name,
    warehouses.city as warehouse_city,
    warehouses.state_code as warehouse_state_code,
    warehouses.region as warehouse_region,
    warehouses.warehouse_status,

    orders.order_status,
    orders.service_level,

    case
        when orders.is_cancelled_order then 'cancelled'
        when orders.order_status = 'delivered' then 'delivered'
        else 'active'
    end as flow_status,

    order_stage_snapshot.stage_sequence,
    order_stage_snapshot.stage_code,
    order_stage_snapshot.stage_name,
    order_stage_snapshot.stage_status,
    order_stage_snapshot.stage_started_at,
    order_stage_snapshot.stage_finished_at,
    order_stage_snapshot.stage_duration_hours,

    stage_monitoring.stage_age_hours,

    case
        when order_stage_snapshot.is_current_stage
            then stage_monitoring.stage_age_hours
        else order_stage_snapshot.stage_duration_hours
    end as stage_elapsed_hours,

    order_stage_snapshot.is_completed_stage,
    order_stage_snapshot.is_current_stage,
    order_stage_snapshot.is_cancelled_in_stage,

    stage_monitoring.analysis_timestamp,
    stage_monitoring.completed_stage_count,
    stage_monitoring.average_duration_hours,
    stage_monitoring.median_duration_hours,
    stage_monitoring.p75_duration_hours,
    stage_monitoring.p90_duration_hours,
    stage_monitoring.critical_threshold_hours,
    stage_monitoring.stage_variance_hours,
    stage_monitoring.stage_age_ratio,
    stage_monitoring.hours_until_promised_delivery,
    stage_monitoring.is_above_average,
    stage_monitoring.is_above_critical_threshold,
    stage_monitoring.stage_signal,
    stage_monitoring.signal_reason,
    stage_monitoring.signal_priority,

    coalesce(
        stage_monitoring.is_above_critical_threshold,
        false
    ) as requires_attention,

    coalesce(
        order_stage_snapshot.is_late,
        false
    ) as is_late,

    orders.subtotal_amount,
    orders.discount_amount,
    orders.net_merchandise_amount,
    orders.shipping_amount,
    orders.tax_amount,
    orders.total_amount,

    orders.created_at as order_created_at,
    orders.updated_at as order_updated_at,
    orders.promised_delivery_at,
    orders.cancelled_at,
    orders.cancellation_reason,

    1 as order_count,

    case
        when orders.is_cancelled_order then 0
        when orders.order_status = 'delivered' then 0
        else 1
    end as active_order_count,

    case
        when orders.is_cancelled_order then 1
        else 0
    end as cancelled_order_count,

    case
        when orders.order_status = 'delivered' then 1
        else 0
    end as delivered_order_count

from order_stage_snapshot

inner join orders
    on order_stage_snapshot.order_id = orders.order_id

left join stage_monitoring
    on order_stage_snapshot.order_id = stage_monitoring.order_id

left join customers
    on orders.customer_id = customers.customer_id

left join warehouses
    on orders.warehouse_id = warehouses.warehouse_id