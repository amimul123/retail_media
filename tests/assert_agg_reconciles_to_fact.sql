{{ config(severity='error') }}
{# The dashboard table must neither lose nor duplicate rows relative to the fact (join fan-out guard). #}
select 
        a.impressions as agg_impressions, 
        f.impressions as fact_impressions,
        a.clicks as agg_clicks, 
        f.clicks as fact_clicks
from 
    (select sum(impressions) as impressions, sum(clicks) as clicks from {{ ref('agg_campaign_performance_daily') }}) a
cross join 
    (select sum(impressions) as impressions, sum(clicks) as clicks from {{ ref('fct_campaign_performance_daily') }}) f
where a.impressions <> f.impressions or a.clicks <> f.clicks
