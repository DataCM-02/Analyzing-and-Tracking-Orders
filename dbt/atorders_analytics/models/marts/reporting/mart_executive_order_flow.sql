{{ config(materialized='table') }}

with stage_history as (

    select
        stage_sequence,
        stage_code,
        stage_name,

        count(distinct order_id) as entered_order_count,

        count(*) filter (
            where is_completed_stage
        ) as completed_order_count,

        count(*) filter (
            where is_cancelled_in_stage
        ) as cancelled_order_count,

        round(
            avg(stage_duration_hours) filter (
                where is_completed_stage
                  and stage_duration_hours is not null
            ),
            2
        ) as average_completed_duration_hours,

        round(
            (
                percentile_cont(0.50) within group (
                    order by stage_duration_hours
                ) filter (
                    where is_completed_stage
                      and stage_duration_hours is not null
                )
            )::numeric,
            2
        ) as median_completed_duration_hours,

        round(
            (
                percentile_cont(0.75) within group (
                    order by stage_duration_hours
                ) filter (
                    where is_completed_stage
                      and stage_duration_hours is not null
                )
            )::numeric,
            2
        ) as p75_completed_duration_hours,

        round(
            (
                percentile_cont(0.90) within group (
                    order by stage_duration_hours
                ) filter (
                    where is_completed_stage
                      and stage_duration_hours is not null
                )
            )::numeric,
            2
        ) as p90_completed_duration_hours

    from {{ ref('fct_order_stage') }}

    group by
        stage_sequence,
        stage_code,
        stage_name

),

current_flow as (

    select
        stage_sequence,
        stage_code,
        stage_name,

        count(*) filter (
            where flow_status = 'active'
        ) as current_order_count,

        count(*) filter (
            where flow_status = 'active'
              and is_late
        ) as late_current_order_count,

        count(*) filter (
            where flow_status = 'active'
              and stage_signal = 'green'
        ) as green_order_count,

        count(*) filter (
            where flow_status = 'active'
              and stage_signal = 'yellow'
        ) as yellow_order_count,

        count(*) filter (
            where flow_status = 'active'
              and stage_signal = 'red'
        ) as red_order_count,

        count(*) filter (
            where flow_status = 'active'
              and requires_attention
        ) as attention_order_count,

        round(
            avg(stage_age_hours) filter (
                where flow_status = 'active'
            ),
            2
        ) as average_current_age_hours,

        round(
            max(stage_age_hours) filter (
                where flow_status = 'active'
            ),
            2
        ) as maximum_current_age_hours,

        coalesce(
            sum(total_amount) filter (
                where flow_status = 'active'
            ),
            0
        ) as active_order_amount,

        coalesce(
            sum(total_amount) filter (
                where flow_status = 'cancelled'
            ),
            0
        ) as cancelled_order_amount,

        coalesce(
            sum(total_amount) filter (
                where flow_status = 'delivered'
            ),
            0
        ) as delivered_order_amount

    from {{ ref('mart_control_tower') }}

    group by
        stage_sequence,
        stage_code,
        stage_name

),

combined as (

    select
        stage_history.stage_sequence,
        stage_history.stage_code,
        stage_history.stage_name,

        stage_history.entered_order_count,
        stage_history.completed_order_count,
        stage_history.cancelled_order_count,

        coalesce(
            current_flow.current_order_count,
            0
        ) as current_order_count,

        coalesce(
            current_flow.late_current_order_count,
            0
        ) as late_current_order_count,

        coalesce(
            current_flow.green_order_count,
            0
        ) as green_order_count,

        coalesce(
            current_flow.yellow_order_count,
            0
        ) as yellow_order_count,

        coalesce(
            current_flow.red_order_count,
            0
        ) as red_order_count,

        coalesce(
            current_flow.attention_order_count,
            0
        ) as attention_order_count,

        stage_history.average_completed_duration_hours,
        stage_history.median_completed_duration_hours,
        stage_history.p75_completed_duration_hours,
        stage_history.p90_completed_duration_hours,

        current_flow.average_current_age_hours,
        current_flow.maximum_current_age_hours,

        coalesce(
            current_flow.active_order_amount,
            0
        ) as active_order_amount,

        coalesce(
            current_flow.cancelled_order_amount,
            0
        ) as cancelled_order_amount,

        coalesce(
            current_flow.delivered_order_amount,
            0
        ) as delivered_order_amount

    from stage_history

    left join current_flow
        on stage_history.stage_code = current_flow.stage_code

)

select
    stage_sequence,
    stage_code,
    stage_name,

    entered_order_count,
    completed_order_count,
    current_order_count,
    cancelled_order_count,

    round(
        (
            completed_order_count::numeric
            / nullif(entered_order_count, 0)
        ) * 100,
        2
    ) as stage_completion_percentage,

    round(
        (
            cancelled_order_count::numeric
            / nullif(entered_order_count, 0)
        ) * 100,
        2
    ) as stage_cancellation_percentage,

    round(
        (
            current_order_count::numeric
            / nullif(
                sum(current_order_count) over (),
                0
            )
        ) * 100,
        2
    ) as active_flow_percentage,

    average_completed_duration_hours,
    median_completed_duration_hours,
    p75_completed_duration_hours,
    p90_completed_duration_hours,

    average_current_age_hours,
    maximum_current_age_hours,

    late_current_order_count,
    green_order_count,
    yellow_order_count,
    red_order_count,
    attention_order_count,

    case
        when red_order_count > 0 then 'red'
        when yellow_order_count > 0 then 'yellow'
        when current_order_count > 0 then 'green'
        else 'neutral'
    end as stage_signal,

    active_order_amount,
    cancelled_order_amount,
    delivered_order_amount

from combined

order by stage_sequence