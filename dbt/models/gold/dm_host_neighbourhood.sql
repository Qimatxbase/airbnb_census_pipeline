{{ config(schema='gold', alias='dm_host_neighbourhood', materialized='view') }}
with f as (
  select listing_id, month, host_id, is_active, est_revenue
  from {{ ref('fact_listing') }}
),
s_latest as (
  select
    listing_id,
    source_month,
    host_lga_code,
    host_lga_name,
    listing_lga_code,
    listing_lga_name,
    valid_ts,
    row_number() over (partition by listing_id, source_month order by valid_ts desc) as rn
  from {{ ref('dim_suburb') }}
),
s as (
  select
    listing_id,
    source_month,
    coalesce(host_lga_code, listing_lga_code) as lga_code,
    coalesce(host_lga_name, listing_lga_name) as lga_name
  from s_latest
  where rn = 1
),
j as (
  select
    s.lga_code,
    s.lga_name,
    f.month,
    f.host_id,
    f.is_active,
    f.est_revenue
  from f
  left join s
    on s.listing_id = f.listing_id and s.source_month = f.month
)

select
  lga_code  as host_neighbourhood_lga_code,
  lga_name  as host_neighbourhood_lga_name,
  month,
  count(distinct host_id)                                                                 as number_of_distinct_host,
  avg(est_revenue) filter (where is_active)                                               as avg_estimated_revenue_per_active_listings,
  sum(est_revenue) filter (where is_active) / nullif(count(distinct host_id), 0)          as estimated_revenue_per_host_distinct
from j
where lga_code is not null
group by 1,2,3
order by host_neighbourhood_lga_code, host_neighbourhood_lga_name, month
