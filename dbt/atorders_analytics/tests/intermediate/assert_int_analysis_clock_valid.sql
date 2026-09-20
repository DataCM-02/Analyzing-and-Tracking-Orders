with clock_validation as (

    select
        count(*) as clock_row_count,
        max(analysis_timestamp) as analysis_timestamp

    from {{ ref('int_analysis_clock') }}

),

source_clock as (

    select
        max(received_at) as expected_analysis_timestamp

    from {{ ref('stg_ecommerce__order_events') }}

)

select
    clock_validation.clock_row_count,
    clock_validation.analysis_timestamp,
    source_clock.expected_analysis_timestamp

from clock_validation

cross join source_clock

where clock_validation.clock_row_count <> 1
   or clock_validation.analysis_timestamp
      is distinct from source_clock.expected_analysis_timestamp