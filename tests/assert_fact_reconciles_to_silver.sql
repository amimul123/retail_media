{{ config(severity='error') }}
{# Reconciliation: the fact must equal the event-level silver for every day in the last 30 loaded days. #}
with bounds as (select max(event_date) as d1 from {{ ref('fct_campaign_performance_daily') }}),
s as (
    select event_date,
           sum(case when event_type = 'impression' then 1 else 0 end) as impressions,
           sum(case when event_type = 'click' then 1 else 0 end)      as clicks
    from {{ ref('int_tracking_events') }}, bounds
    where event_date > bounds.d1 - 30
    group by 1
),
f as (
    select 
        event_date, 
        sum(impressions)    as impressions, 
        sum(clicks)         as clicks
    from {{ ref('fct_campaign_performance_daily') }}, bounds
    where event_date > bounds.d1 - 30
    group by 1
)
select 
        coalesce(s.event_date, f.event_date) as event_date,
        s.impressions as silver_impressions, 
        f.impressions as fact_impressions,
        s.clicks as silver_clicks, 
        f.clicks as fact_clicks
from s full outer join f using (event_date)
where coalesce(s.impressions, -1) <> coalesce(f.impressions, -1)
   or coalesce(s.clicks, -1) <> coalesce(f.clicks, -1)
