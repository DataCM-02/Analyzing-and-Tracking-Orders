select
    order_id,
    current_stage,
    payment_approval_hours,
    allocation_wait_hours,
    picking_hours,
    packing_hours,
    dispatch_hours,
    transit_hours,
    total_cycle_hours,
    current_stage_age_hours
from {{ ref('int_order_lifecycle') }}
where
    payment_approval_hours < 0
    or allocation_wait_hours < 0
    or picking_hours < 0
    or packing_hours < 0
    or dispatch_hours < 0
    or transit_hours < 0
    or total_cycle_hours < 0
    or current_stage_age_hours < 0