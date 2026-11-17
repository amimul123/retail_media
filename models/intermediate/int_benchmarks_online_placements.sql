
select
    campaign_key,
    start_date                                as benchmark_start_date,
    end_date                                  as benchmark_end_date,
    cast(benchmark_ctr as double precision)   as benchmark_ctr,
    cast(reach as double precision)           as benchmark_weight
from {{ ref('int_online_placement_flights') }}
where is_usable_for_benchmark
