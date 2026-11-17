{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='event_date',
        on_schema_change='fail'
    )
}}
{# Grain: business date x campaign x device. Additive measures only (impressions, clicks). #}
select
    cast(to_char(event_date, 'YYYYMMDD') as integer)                           as date_key,
    event_date,
    campaign_key,
    {{ surrogate_hash('device') }}                                             as device_key,
    cast(sum(case when event_type = 'impression' then 1 else 0 end) as bigint) as impressions,
    cast(sum(case when event_type = 'click' then 1 else 0 end) as bigint)      as clicks,
    cast(current_timestamp as timestamp)                                       as processed_at
from {{ ref('int_tracking_events') }}
where event_date between {{ window_start() }} and {{ window_end() }}
group by 
    event_date, campaign_key, device
