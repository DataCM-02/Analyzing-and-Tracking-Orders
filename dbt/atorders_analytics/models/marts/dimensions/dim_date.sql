with date_boundaries as (

    select
        date_trunc('year', min(created_at))::date as start_date,
        (
            date_trunc('year', max(promised_delivery_at))
            + interval '1 year'
            - interval '1 day'
        )::date as end_date

    from {{ ref('stg_ecommerce__orders') }}

),

date_spine as (

    select
        generated_date::date as date_day

    from date_boundaries
    cross join lateral generate_series(
        start_date,
        end_date,
        interval '1 day'
    ) as generated_date

)

select
    to_char(date_day, 'YYYYMMDD')::integer as date_key,
    date_day,

    extract(year from date_day)::smallint as year_number,
    extract(quarter from date_day)::smallint as quarter_number,
    ('Q' || extract(quarter from date_day)::integer)::text
        as quarter_name,

    extract(month from date_day)::smallint as month_number,

    case extract(month from date_day)::integer
        when 1 then 'January'
        when 2 then 'February'
        when 3 then 'March'
        when 4 then 'April'
        when 5 then 'May'
        when 6 then 'June'
        when 7 then 'July'
        when 8 then 'August'
        when 9 then 'September'
        when 10 then 'October'
        when 11 then 'November'
        when 12 then 'December'
    end as month_name,

    to_char(date_day, 'YYYY-MM') as year_month,
    extract(week from date_day)::smallint as week_of_year,
    extract(isodow from date_day)::smallint as day_of_week_number,

    case extract(isodow from date_day)::integer
        when 1 then 'Monday'
        when 2 then 'Tuesday'
        when 3 then 'Wednesday'
        when 4 then 'Thursday'
        when 5 then 'Friday'
        when 6 then 'Saturday'
        when 7 then 'Sunday'
    end as day_of_week_name,

    extract(day from date_day)::smallint as day_of_month,
    extract(isodow from date_day) in (6, 7) as is_weekend

from date_spine