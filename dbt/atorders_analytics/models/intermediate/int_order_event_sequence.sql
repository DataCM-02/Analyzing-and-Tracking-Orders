with events as (

    select
        event_record_id,
        event_id,
        order_id,
        event_type,
        event_time,
        received_at,
        source_system,
        event_payload
    from {{ ref("stg_ecommerce__order_events") }}

),

sequenced as (

    select
        event_record_id,
        event_id,
        order_id,
        event_type,
        event_time,
        received_at,
        source_system,
        event_payload,

        row_number() over (
            partition by order_id
            order by event_time, event_record_id
        ) as event_sequence_number,

        lag(event_type) over (
            partition by order_id
            order by event_time, event_record_id
        ) as previous_event_type,

        lag(event_time) over (
            partition by order_id
            order by event_time, event_record_id
        ) as previous_event_time,

        lead(event_type) over (
            partition by order_id
            order by event_time, event_record_id
        ) as next_event_type,

        lead(event_time) over (
            partition by order_id
            order by event_time, event_record_id
        ) as next_event_time

    from events

),

calculated as (

    select
        event_record_id,
        event_id,
        order_id,
        event_type,
        event_time,
        received_at,
        source_system,
        event_payload,
        event_sequence_number,
        previous_event_type,
        previous_event_time,
        next_event_type,
        next_event_time,

        case
            when previous_event_time is not null
                then round(
                    (
                        extract(epoch from (event_time - previous_event_time))
                        / 3600.0
                    )::numeric,
                    2
                )
        end as hours_since_previous_event,

        round(
            (
                extract(epoch from (received_at - event_time))
                / 60.0
            )::numeric,
            2
        ) as ingestion_delay_minutes

    from sequenced

)

select *
from calculated