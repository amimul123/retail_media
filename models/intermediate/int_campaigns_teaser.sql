{# Conformed campaign contract (enforced in silver.yml). Every new campaign source emits exactly this shape. #}
select
    {{ campaign_key("'teaser'", 'cast(campaign_id as text)', 'campaign_name_key') }} as campaign_key,
    cast('teaser' as text)             as campaign_type,
    cast('cms' as text)                as source_system,
    cast(campaign_id as text)          as source_campaign_id,
    campaign_name,
    campaign_name_key,
    gender,
    active_from_date                      as campaign_start_date,
    active_to_date                        as campaign_end_date,
    is_in_latest_snapshot                 as is_currently_listed_in_source,
    has_missing_required_fields
from {{ ref('int_teasers') }}
