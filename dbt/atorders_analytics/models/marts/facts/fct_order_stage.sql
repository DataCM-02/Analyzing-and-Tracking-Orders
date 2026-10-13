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

),

orders as (

    select
        order_id,
        created_at as order_created_at

    from {{ ref('stg_ecommerce__orders') }}

)

select
    md5(
        concat_ws(
            '|',
            stage_history.order_id::text,
            stage_history.stage_code
        )
    ) as order_stage_key,

    stage_history.order_id,
    stage_history.order_number,

    stage_history.customer_id,
    stage_history.warehouse_id,

    to_char(orders.order_created_at, 'YYYYMMDD')::integer
        as order_date_key,

    to_char(
        stage_history.stage_started_at,
        'YYYYMMDD'
    )::integer as stage_started_date_key,

    to_char(
        stage_history.stage_finished_at,
        'YYYYMMDD'
    )::integer as stage_finished_date_key,

    to_char(
        stage_history.promised_delivery_at,
        'YYYYMMDD'
    )::integer as promised_delivery_date_key,

    stage_history.service_level,
    stage_history.order_current_stage,

    stage_history.stage_sequence,
    stage_history.stage_code,
    stage_history.stage_name,
    stage_history.stage_status,

    orders.order_created_at,
    stage_history.stage_started_at,
    stage_history.stage_finished_at,
    stage_history.stage_duration_hours,
    stage_history.stage_age_hours,

    stage_history.promised_delivery_at,
    stage_history.order_delivered_at,
    stage_history.order_cancelled_at,

    stage_history.is_completed_stage,
    stage_history.is_current_stage,
    stage_history.is_cancelled_in_stage,
    stage_history.is_late

from stage_history

inner join orders
    on stage_history.order_id = orders.order_id