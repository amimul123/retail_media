{#
  Volume anomaly + gap detection per campaign_type, on the small fact table.
  is_volume_anomaly: |impressions / trailing-7-day-avg - 1| > threshold (needs >= min history days).
  Missing days between first and last date are materialised with 0 so outages show up as -100%.
#}
with daily as (
    select f.event_date, c.campaign_type, sum(f.impressions) as impressions, sum(f.clicks) as clicks
    from {{ ref('fct_campaign_performance_daily') }} f
    join {{ ref('dim_campaign') }} c using (campaign_key)
    group by 1, 2
),
types as (select distinct campaign_type from daily),
bounds as (select min(event_date) as d0, max(event_date) as d1 from daily),
spine as (
    select d.date_day as event_date, t.campaign_type
    from {{ ref('dim_date') }} d cross join bounds b cross join types t
    where d.date_day between b.d0 and b.d1
),
filled as (
    select s.event_date, s.campaign_type,
        coalesce(d.impressions, 0) as impressions, coalesce(d.clicks, 0) as clicks,
        (d.event_date is null) as is_missing_day
    from spine s left join daily d using (event_date, campaign_type)
),
scored as (
    select *,
        avg(impressions) over w as trailing_avg_impressions,
        count(*) over w         as trailing_days
    from filled
    window w as (partition by campaign_type order by event_date rows between 7 preceding and 1 preceding)
)
select
    event_date, 
    campaign_type, 
    impressions, 
    clicks, 
    is_missing_day,
    trailing_avg_impressions, 
    trailing_days,
    impressions / nullif(trailing_avg_impressions, 0) - 1 as pct_vs_trailing_avg,
    (trailing_days >= {{ var('volume_min_history_days') }}
     and abs(impressions / nullif(trailing_avg_impressions, 0) - 1) > {{ var('volume_anomaly_threshold') }}) as is_volume_anomaly
from scored
