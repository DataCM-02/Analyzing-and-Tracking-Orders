{{ config(materialized='view') }}

select
    max(received_at) as analysis_timestamp

from {{ ref('stg_ecommerce__order_events') }}