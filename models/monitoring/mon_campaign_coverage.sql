{# Share of impressions that cannot be fully attributed (no metadata / unknown gender / unmapped device). #}
select
    a.event_date,
    a.campaign_type,
    sum(a.impressions)                                                                   as impressions,
    sum(case when not c.has_source_metadata then a.impressions else 0 end)               as impressions_without_metadata,
    sum(case when a.gender = 'Unknown' then a.impressions else 0 end)                    as impressions_unknown_gender,
    sum(case when a.device in ('unknown', 'other') then a.impressions else 0 end)        as impressions_unmapped_device,
    {{ safe_divide("sum(case when not c.has_source_metadata then a.impressions else 0 end)", 'sum(a.impressions)') }} as pct_without_metadata,
    {{ safe_divide("sum(case when a.gender = 'Unknown' then a.impressions else 0 end)", 'sum(a.impressions)') }}      as pct_unknown_gender
from {{ ref('agg_campaign_performance_daily') }} a
join {{ ref('dim_campaign') }} c using (campaign_key)
group by 1, 2
