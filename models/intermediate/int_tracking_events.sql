{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='event_date',
        on_schema_change='sync_all_columns'
    )
}}

with src as (

    select *
    from {{ ref('stg_tracking_events') }}
    where event_timestamp is not null
      and event_timestamp >= {{ window_start() }} - 1
      and event_timestamp <  {{ window_end() }} + 2

),

typed as (

    select
        {{ clean_text('session_id') }}                  as session_id,
        {{ clean_text('visitor_id') }}                  as visitor_id,
        event_timestamp                                 as event_ts_utc,
        {{ to_local_date('event_timestamp') }}          as event_date,
        lower({{ clean_text('event_type') }})           as event_type,
        coalesce(lower({{ clean_text('campaign_type') }}), 'unknown') as campaign_type,
        {{ clean_id('campaign_id') }}                   as source_campaign_id,
        {{ clean_text('campaign_name') }}               as campaign_name,
        lower({{ clean_text('device') }})               as device_raw,
        _batch_id,
        _loaded_at,
        _row_number
    from src

),

filtered as (

    select *, 
            {{ name_key('campaign_name') }} as campaign_name_key
    from typed
    where event_date between {{ window_start() }} and {{ window_end() }}
      and event_type in ({{ "'" ~ var('valid_event_types') | join("','") ~ "'" }})

),

keyed as (

    select
        f.*,
        {{ surrogate_hash("coalesce(session_id,'') || '|' || coalesce(visitor_id,'') || '|' || cast(event_ts_utc as text) || '|' || event_type || '|' || campaign_type || '|' || coalesce(source_campaign_id,'') || '|' || coalesce(campaign_name_key,'')") }} as event_id,
        {{ campaign_key('campaign_type', 'source_campaign_id', 'campaign_name_key') }} as campaign_key,
        coalesce(m.device, case when f.device_raw is null then 'unknown' else 'other' end) as device
    from filtered f
    left join {{ ref('device_mapping') }} m on m.raw_value = f.device_raw

),

deduped as (

    -- GA4 exports can contain exact duplicates (re-sends / double loads): keep one
    select *, 
            row_number() over (
                partition by event_id order by _loaded_at desc, _row_number desc
            ) as rn
    from keyed

)

select
    event_id, 
    session_id, 
    visitor_id, 
    event_ts_utc, 
    event_date, 
    event_type, 
    device, 
    device_raw,
    campaign_type, 
    source_campaign_id, 
    campaign_name, 
    campaign_name_key, 
    campaign_key,
    _batch_id,
    _loaded_at
from deduped
where rn = 1
