
with flights as (

    select * from {{ ref('int_online_placement_flights') }}
    where campaign_name_key is not null

),

latest_name as (

    select campaign_name_key, campaign_name,
        row_number() over (partition by campaign_name_key order by start_date desc nulls last, _loaded_at desc) as rn
    from flights

),

agg as (

    select
        campaign_name_key,
        min(campaign_key)                                              as campaign_key,
        case 
            when count(distinct gender) = 1 then min(gender) 
            else 'Mixed' 
        end as gender,
        min(start_date)                                                as campaign_start_date,
        max(end_date)                                                  as campaign_end_date,
        bool_or(has_missing_required_fields)                           as has_missing_required_fields
    from flights
    group by campaign_name_key

)

select
    a.campaign_key,
    cast('online_placement' as text)       as campaign_type,
    cast('salesforce_sheet' as text)       as source_system,
    cast(null as text)                     as source_campaign_id,
    n.campaign_name,
    a.campaign_name_key,
    a.gender,
    a.campaign_start_date,
    a.campaign_end_date,
    cast(true as boolean)                  as is_currently_listed_in_source,
    a.has_missing_required_fields
from agg a
join latest_name n on n.campaign_name_key = a.campaign_name_key and n.rn = 1
