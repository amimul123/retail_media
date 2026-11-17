
with src as (

    select * from {{ ref('stg_online_placements_salesforce') }}

),

cleaned as (

    select
        {{ clean_text('campaign_name') }}                                   as campaign_name,
        {{ name_key(clean_text('campaign_name')) }}                         as campaign_name_key,
        {{ normalize_gender('gender') }}                                    as gender,
        coalesce({{ clean_text('country_cluster') }}, 'Unknown')            as country_cluster,
        campaign_start                                                      as start_date,
        campaign_end                                                        as end_date,
        reach,
        {{ clean_text('currency_cpm') }}                                    as currency_cpm,
        cpm,
        {{ parse_percent(clean_text('benchmark_ctr_raw')) }}                as benchmark_ctr,
        benchmark_clicks,
        _batch_id,
        _loaded_at,
        _row_number
    from src

),

deduped as (

    -- the sheet is re-exported repeatedly: same business key => keep the latest export
    select *,
        row_number() over (
            partition by campaign_name_key, gender, country_cluster, start_date, end_date
            order by _loaded_at desc, _row_number desc
        ) as rn
    from cleaned

),

flagged as (

    select
        {{ surrogate_hash("coalesce(campaign_name_key,'') || '|' || gender || '|' || country_cluster || '|' || coalesce(cast(start_date as text),'') || '|' || coalesce(cast(end_date as text),'')") }} as flight_key,
        {{ campaign_key("'online_placement'", 'cast(null as text)', 'campaign_name_key') }} as campaign_key,
        campaign_name,
        campaign_name_key, 
        gender, 
        country_cluster,
        start_date, 
        end_date, 
        reach, 
        currency_cpm, 
        cpm, 
        benchmark_ctr, 
        benchmark_clicks,

        -- quality flags
        (coalesce(reach, 0) = 0 and coalesce(cpm, 0) = 0)                               as is_placeholder,
        (start_date is not null and end_date is not null and end_date >= start_date)    as has_valid_dates,
        (campaign_name is null or gender = 'Unknown' or 
            start_date is null or end_date is null)                                     as has_missing_required_fields,
        (benchmark_ctr is not null and benchmark_clicks is not null and coalesce(reach, 0) > 0
            and abs(benchmark_clicks - reach * benchmark_ctr)
            > {{ var('benchmark_click_tolerance') }} * greatest(reach * benchmark_ctr, 1)) as benchmark_clicks_inconsistent,
        _batch_id, 
        _loaded_at
    from deduped
    where rn = 1

)

select
    *,
    (    campaign_name_key is not null
     and not is_placeholder
     and has_valid_dates
     and benchmark_ctr is not null and benchmark_ctr between 0 and 1
     and coalesce(reach, 0) > 0
    ) as is_usable_for_benchmark
from flagged
