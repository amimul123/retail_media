{#
  DASHBOARD TABLE. Grain: date x campaign x device (gender is a campaign attribute, denormalised here).

#}
select
    f.event_date,
    f.date_key,
    f.campaign_key,
    c.campaign_id,
    c.campaign_name,
    c.campaign_type,
    c.gender,
    d.device_name                                                   as device,
    f.impressions,
    f.clicks,
    {{ safe_divide('f.clicks', 'f.impressions') }}                  as ctr,
    cast(b.benchmark_ctr as double precision)                                    as benchmark_ctr,
    cast(case when b.benchmark_ctr is not null then f.impressions end as bigint) as benchmark_impressions,
    cast(f.impressions * b.benchmark_ctr as double precision)                 as benchmark_expected_clicks,
    cast(case when b.benchmark_ctr is not null then f.clicks end as bigint)   as benchmark_matched_clicks,
    cast({{ safe_divide('f.clicks', 'f.impressions') }} / nullif(b.benchmark_ctr, 0) as double precision) as ctr_vs_benchmark_index
from {{ ref('fct_campaign_performance_daily') }} f
join {{ ref('dim_campaign') }} c on c.campaign_key = f.campaign_key
join {{ ref('dim_device') }}   d on d.device_key   = f.device_key
left join {{ ref('fct_campaign_benchmark_daily') }} b
       on b.campaign_key = f.campaign_key and b.date_day = f.event_date
