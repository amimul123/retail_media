{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='campaign_key'
    )
}}

with ev as (

    select  campaign_key, 
            campaign_type, 
            source_campaign_id, 
            campaign_name_key, 
            campaign_name, 
            event_ts_utc, 
            event_date
    from    {{ ref('int_tracking_events') }}
    where   event_date between {{ window_start('last_seen_date') }} and {{ window_end() }}

),

ranked as (

    select *, row_number() over (partition by campaign_key order by event_ts_utc desc) as rn from ev

),

latest as (

    select 
            campaign_key, 
            campaign_type, 
            source_campaign_id, 
            campaign_name_key, 
            campaign_name as latest_campaign_name
    from    ranked 
    where rn = 1

),

span as (

    select 
            campaign_key, 
            min(event_date) as first_seen_date, 
            max(event_date) as last_seen_date
    from    ev 
    group by campaign_key

),

new_rows as (

    select  
            l.*, 
            s.first_seen_date, 
            s.last_seen_date
    from    latest l 
    join    span s using (campaign_key)

)

{% if is_incremental() %}
select
        n.campaign_key, 
        n.campaign_type, 
        n.source_campaign_id, 
        n.campaign_name_key,
        case 
            when t.campaign_key is null or n.last_seen_date >= t.last_seen_date
                then n.latest_campaign_name 
                else t.latest_campaign_name 
        end as latest_campaign_name,
        least(n.first_seen_date, coalesce(t.first_seen_date, n.first_seen_date))   as first_seen_date,
        greatest(n.last_seen_date, coalesce(t.last_seen_date, n.last_seen_date))   as last_seen_date
from    new_rows n
left join {{ this }} t on t.campaign_key = n.campaign_key
{% else %}
select 
    campaign_key, 
    campaign_type, 
    source_campaign_id, 
    campaign_name_key, 
    latest_campaign_name, 
    first_seen_date, 
    last_seen_date
from new_rows
{% endif %}
