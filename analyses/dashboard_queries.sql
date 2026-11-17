
-- 1) KPI tiles ------------------------------------------------------------------------------------
select
    sum(impressions)                                                          as impressions,
    sum(clicks)                                                               as clicks,
    sum(clicks) * 1.0 / nullif(sum(impressions), 0)                           as ctr,
    -- benchmark only over impressions that have a benchmark (online placements)
    sum(benchmark_expected_clicks) / nullif(sum(benchmark_impressions), 0)    as benchmark_ctr
from mart.agg_campaign_performance_daily
where event_date between :start_date and :end_date
  and (campaign_id in (:campaign_ids) or :campaign_ids is null)
  and device in (:devices)
  and gender in (:genders);

-- 2) Daily trend: actual vs benchmark ----------------------------------------------------------------
select
    event_date,
    sum(impressions)                                                          as impressions,
    sum(clicks) * 1.0 / nullif(sum(impressions), 0)                           as ctr,
    sum(benchmark_expected_clicks) / nullif(sum(benchmark_impressions), 0)    as benchmark_ctr
from mart.agg_campaign_performance_daily
where event_date between :start_date and :end_date
group by event_date
order by event_date;

-- 3) Campaign table (ID / name filter, CTR vs benchmark index) ---------------------------------------
select
    campaign_type,
    campaign_id,
    campaign_name,
    gender,
    sum(impressions)                                                          as impressions,
    sum(clicks)                                                               as clicks,
    sum(clicks) * 1.0 / nullif(sum(impressions), 0)                           as ctr,
    sum(benchmark_expected_clicks) / nullif(sum(benchmark_impressions), 0)    as benchmark_ctr,
    (sum(benchmark_matched_clicks) * 1.0 / nullif(sum(benchmark_impressions), 0))
      / nullif(sum(benchmark_expected_clicks) / nullif(sum(benchmark_impressions), 0), 0) as ctr_vs_benchmark_index
from mart.agg_campaign_performance_daily
where event_date between :start_date and :end_date
group by campaign_type, campaign_id, campaign_name, gender
order by impressions desc;

-- 4) Device split -----------------------------------------------------------------------------------
select device, sum(impressions) as impressions, sum(clicks) * 1.0 / nullif(sum(impressions), 0) as ctr
from mart.agg_campaign_performance_daily
where event_date between :start_date and :end_date
group by device;

-- 5) Gender split (campaign target gender) ----------------------------------------------------------
select gender, sum(impressions) as impressions, sum(clicks) * 1.0 / nullif(sum(impressions), 0) as ctr
from mart.agg_campaign_performance_daily
where event_date between :start_date and :end_date
group by gender;

-- 6) Same question straight from the star schema (when you need a dimension the agg does not carry) --
select
    d.iso_year, d.iso_week,
    c.campaign_name,
    dev.device_name,
    sum(f.impressions) as impressions,
    sum(f.clicks)      as clicks,
    sum(f.clicks) * 1.0 / nullif(sum(f.impressions), 0) as ctr
from mart.fct_campaign_performance_daily f
join mart.dim_date     d   on d.date_day   = f.event_date
join mart.dim_campaign c   on c.campaign_key = f.campaign_key
join mart.dim_device   dev on dev.device_key = f.device_key
where f.event_date between :start_date and :end_date
group by 1, 2, 3, 4;
