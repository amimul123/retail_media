{{ config(severity='warn') }}
{# Volume drops/spikes and missing days vs the trailing 7-day average (tracking outage, double load, tag change). #}
select 
        * 
from {{ ref('mon_daily_volume') }}
where is_volume_anomaly or is_missing_day
