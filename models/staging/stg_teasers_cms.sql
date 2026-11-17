select
    campaign_id                                                          as campaign_id_raw,
    {{ safe_cast("nullif(trim(campaign_id), '')", 'bigint') }}           as campaign_id,
    campaign_name,
    gender,
    active_from                                                          as active_from_raw,
    {{ safe_cast("nullif(trim(active_from), '')", 'timestamp') }}        as active_from,
    active_to                                                            as active_to_raw,
    {{ safe_cast("nullif(trim(active_to), '')", 'timestamp') }}          as active_to,
    _batch_id,
    cast(_loaded_at as timestamp) as _loaded_at,
    _source_file,
    _row_number
from {{ source('raw', 'teasers_cms') }}
