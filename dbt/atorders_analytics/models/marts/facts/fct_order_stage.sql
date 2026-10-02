with stage_history as (

    select
        order_id,
        order_number,
        customer_id,
        warehouse_id,
        service_level,
        promised_delivery_at,
        order_current_stage,
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
        is_late,
        order_delivered_at,
        order_cancelled_at

    from {{ ref('int_order_stage_history') }}

)

select
    md5(
        concat_ws(
            '|',
            order_id::text,
            stage_code
        )
    ) as order_stage_key,

    order_id,
    order_number,

    customer_id,
    warehouse_id,

    to_char(stage_started_at, 'YYYYMMDD')::integer
        as stage_started_date_key,

    to_char(stage_finished_at, 'YYYYMMDD')::integer
        as stage_finished_date_key,

    to_char(promised_delivery_at, 'YYYYMMDD')::integer
        as promised_delivery_date_key,

    service_level,
    order_current_stage,

    stage_sequence,
    stage_code,
    stage_name,
    stage_status,

    stage_started_at,
    stage_finished_at,
    stage_duration_hours,
    stage_age_hours,

    promised_delivery_at,
    order_delivered_at,
    order_cancelled_at,

    is_completed_stage,
    is_current_stage,
    is_cancelled_in_stage,
    is_late

from stage_history