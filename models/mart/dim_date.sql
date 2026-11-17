
with spine as (
    select cast(d as date) as date_day
    from generate_series(cast('{{ var("min_event_date") }}' as date), current_date + 365, interval '1 day') as t(d)
)
select
    cast(to_char(date_day, 'YYYYMMDD') as integer) as date_key,
    date_day,
    cast(extract(year from date_day) as integer)       as year,
    cast(extract(quarter from date_day) as integer)    as quarter,
    cast(extract(month from date_day) as integer)      as month,
    trim(to_char(date_day, 'Month'))                   as month_name,
    cast(extract(isoyear from date_day) as integer)    as iso_year,
    cast(extract(week from date_day) as integer)       as iso_week,
    cast(extract(isodow from date_day) as integer)     as day_of_week,
    trim(to_char(date_day, 'Day'))                     as day_name,
    extract(isodow from date_day) in (6, 7)            as is_weekend
from spine
