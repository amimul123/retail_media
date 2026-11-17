{#
  Expected (benchmark) CTR per campaign and day, only for campaign types that have benchmarks
  (online placements today).
#}
with benchmarks as (
    select * from {{ ref('int_benchmarks_online_placements') }}
)
select
    b.campaign_key,
    d.date_day,
    sum(b.benchmark_ctr * b.benchmark_weight) / nullif(sum(b.benchmark_weight), 0) as benchmark_ctr,
    count(*)                                                                       as n_flights
from benchmarks b
join {{ ref('dim_date') }} d
  on d.date_day between b.benchmark_start_date and b.benchmark_end_date
group by b.campaign_key, d.date_day
