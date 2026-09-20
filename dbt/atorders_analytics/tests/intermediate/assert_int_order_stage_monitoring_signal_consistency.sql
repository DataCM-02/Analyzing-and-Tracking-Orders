with expected_signals as (

    select
        *,

        case
            when is_late
                then 'red'
            when stage_age_hours > critical_threshold_hours
                then 'red'
            when stage_age_hours > average_duration_hours
                then 'yellow'
            else 'green'
        end as expected_signal,

        case
            when is_late
                then 'promised_delivery_overdue'
            when stage_age_hours > critical_threshold_hours
                then 'stage_above_critical_threshold'
            when stage_age_hours > average_duration_hours
                then 'stage_above_average'
            else 'within_average'
        end as expected_reason

    from {{ ref('int_order_stage_monitoring') }}

)

select *

from expected_signals

where stage_age_hours < 0

   or is_above_average is distinct from (
       stage_age_hours > average_duration_hours
   )

   or is_above_critical_threshold is distinct from (
       stage_age_hours > critical_threshold_hours
   )

   or stage_signal is distinct from expected_signal

   or signal_reason is distinct from expected_reason

   or signal_priority is distinct from (
       case expected_signal
           when 'red' then 3
           when 'yellow' then 2
           when 'green' then 1
       end
   )