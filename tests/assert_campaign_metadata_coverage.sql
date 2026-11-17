{{ config(severity='warn') }}
{# More than 5% of a day's impressions belong to campaigns without source metadata, or have unknown gender. #}
select 
        * 
from {{ ref('mon_campaign_coverage') }}
where pct_without_metadata > 0.05 or pct_unknown_gender > 0.05
