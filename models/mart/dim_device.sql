with devices as (
    select distinct device as device_name from {{ ref('device_mapping') }}
    union
    select 'unknown'     -- device missing in tracking
    union
    select 'other'       -- device value not covered by seeds/device_mapping.csv (monitored)
)
select
    {{ surrogate_hash('device_name') }} as device_key,
    device_name
from devices
