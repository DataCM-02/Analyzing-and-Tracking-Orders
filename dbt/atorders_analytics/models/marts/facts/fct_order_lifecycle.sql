with lifecycle as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        current_stage,
        service_level,
        promised_delivery_at,
        order_created_at,
        payment_approved_at,
        order_allocated_at,
        picking_started_at,
        picking_completed_at,
        order_packed_at,
        order_shipped_at,
        in_transit_at,
        first_delivery_attempt_at,
        last_delivery_attempt_at,
        delivery_attempt_count,
        order_delivered_at,
        order_cancelled_at,
        first_event_at,
        last_event_at,
        event_count,
        current_stage_started_at,
        payment_approval_hours,
        allocation_wait_hours,
        picking_hours,
        packing_hours,
        dispatch_hours,
        transit_hours,
        total_cycle_hours,
        current_stage_age_hours,
        is_late,
        is_completed,
        is_cancelled

    from {{ ref('int_order_lifecycle') }}

)

select
    order_id,
    order_number,

    customer_id,
    warehouse_id,

    to_char(order_created_at, 'YYYYMMDD')::integer
        as order_date_key,

    to_char(promised_delivery_at, 'YYYYMMDD')::integer
        as promised_delivery_date_key,

    to_char(order_delivered_at, 'YYYYMMDD')::integer
        as delivered_date_key,

    to_char(order_cancelled_at, 'YYYYMMDD')::integer
        as cancellation_date_key,

    current_stage,
    service_level,

    promised_delivery_at,
    order_created_at,
    payment_approved_at,
    order_allocated_at,
    picking_started_at,
    picking_completed_at,
    order_packed_at,
    order_shipped_at,
    in_transit_at,
    first_delivery_attempt_at,
    last_delivery_attempt_at,
    delivery_attempt_count,
    order_delivered_at,
    order_cancelled_at,

    first_event_at,
    last_event_at,
    event_count,

    current_stage_started_at,

    payment_approval_hours,
    allocation_wait_hours,
    picking_hours,
    packing_hours,
    dispatch_hours,
    transit_hours,
    total_cycle_hours,
    current_stage_age_hours,

    is_late,
    is_completed,
    is_cancelled,

    not is_completed
        and not is_cancelled
        as is_active_order

from lifecycle