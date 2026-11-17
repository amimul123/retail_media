{# BRONZE = typed + renamed view over RAW. No business logic, no row dropping. #}
select
    session_id,
    visitor_id,
    device,
    event_timestamp                                                   as event_timestamp_raw,
    {{ safe_cast("nullif(trim(event_timestamp), '')", 'timestamp') }} as event_timestamp,
    event_type,
    campaign_id,
    campaign_name,
    campaign_type,
    _batch_id,
    cast(_loaded_at as timestamp) as _loaded_at,
    _source_file,
    _row_number
from {{ source('raw', 'tracking_events') }}
