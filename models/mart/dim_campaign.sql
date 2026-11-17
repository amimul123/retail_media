
with src as (
    select * from {{ ref('int_campaigns_unified') }}
),
obs as (
    select * from {{ ref('int_observed_campaigns') }}
)
select
    campaign_key,
    coalesce(s.campaign_type, o.campaign_type)                                    as campaign_type,
    coalesce(s.source_campaign_id, o.source_campaign_id)                          as campaign_id,
    coalesce(s.campaign_name, o.latest_campaign_name, 'Unknown campaign')         as campaign_name,
    coalesce(s.gender, 'Unknown')                                                 as gender,
    s.campaign_start_date,
    s.campaign_end_date,
    s.source_system,
    (s.campaign_key is not null)                                                  as has_source_metadata,
    coalesce(s.is_currently_listed_in_source, false)                              as is_currently_listed_in_source,
    coalesce(s.has_missing_required_fields, false)                                as has_missing_required_fields,
    o.first_seen_date                                                             as first_tracked_date,
    o.last_seen_date                                                              as last_tracked_date
from src s
full outer join obs o using (campaign_key)
