{{ config(severity='error') }}
{# Business rule: benchmark CTR exists for online placements only. #}
select 
        * 
from {{ ref('agg_campaign_performance_daily') }}
where campaign_type <> 'online_placement' and benchmark_ctr is not null
