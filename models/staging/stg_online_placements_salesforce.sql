select
    campaign_start                                  as campaign_start_raw,
    {{ parse_date('campaign_start') }}              as campaign_start,
    campaign_end                                    as campaign_end_raw,
    {{ parse_date('campaign_end') }}                as campaign_end,
    gender,
    country_cluster,
    reach                                           as reach_raw,
    {{ parse_int('reach') }}                        as reach,
    currency_cpm,
    cpm                                             as cpm_raw,
    {{ safe_cast("replace(trim(cpm), ',', '.')", 'double') }} as cpm,
    benchmark_ctr                                   as benchmark_ctr_raw,   -- parsed to a ratio in silver
    benchmark_clicks                                as benchmark_clicks_raw,
    {{ parse_int('benchmark_clicks') }}             as benchmark_clicks,
    campaign_name,
    _batch_id,
    cast(_loaded_at as timestamp) as _loaded_at,
    _source_file,
    _row_number
from {{ source('raw', 'online_placements_salesforce') }}
