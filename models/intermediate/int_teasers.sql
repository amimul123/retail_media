
with src as (

    select *, max(_loaded_at) over () as latest_loaded_at
    from {{ ref('stg_teasers_cms') }}
    where campaign_id is not null               -- unusable without a key (monitored in mon_source_quality)

),

ranked as (

    select *,
        row_number() over (partition by campaign_id order by _loaded_at desc, _row_number desc) as rn,
        min(_loaded_at) over (partition by campaign_id) as first_seen_in_cms_at,
        max(_loaded_at) over (partition by campaign_id) as last_seen_in_cms_at
    from src

)

select
    campaign_id,
    {{ clean_text('campaign_name') }}                      as campaign_name,
    {{ name_key(clean_text('campaign_name')) }}            as campaign_name_key,
    {{ normalize_gender('gender') }}                       as gender,
    active_from                                            as active_from_utc,
    active_to                                              as active_to_utc,
    {{ to_local_date('active_from', 'UTC') }}              as active_from_date,
    {{ to_local_date('active_to', 'UTC') }}                as active_to_date,
    (active_to is null)                                    as is_open_ended,
    (   {{ clean_text('campaign_name') }} is null
     or {{ clean_text('gender') }} is null
     or active_from is null)                               as has_missing_required_fields,
    (last_seen_in_cms_at = latest_loaded_at)               as is_in_latest_snapshot,
    first_seen_in_cms_at,
    last_seen_in_cms_at
from ranked
where rn = 1
