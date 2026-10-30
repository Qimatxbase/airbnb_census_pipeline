{{ config(schema='gold', alias='dm_listing_neighbourhood', materialized='view') }}

with f as (
  select * from {{ ref('fact_listing') }}
),

n_latest as (
  select
    listing_id,
    source_month,
    coalesce(listing_neighbourhood, host_neighbourhood) as listing_neighbourhood,
    row_number() over (partition by listing_id, source_month order by valid_ts desc) as rn
  from {{ ref('dim_suburb') }}
),
n as (
  select listing_id, source_month, listing_neighbourhood
  from n_latest
  where rn = 1
),

h as (
  select host_id, host_is_superhost, valid_from, valid_to
  from {{ ref('host_history') }}
),

j as (
  select
    n.listing_neighbourhood,
    f.month,
    f.listing_id,
    f.host_id,
    f.is_active,
    f.avg_price,
    f.stays,
    f.est_revenue,
    f.avg_review_score,
    h.host_is_superhost
  from f
  left join n
    on n.listing_id = f.listing_id and n.source_month = f.month
  left join h
    on h.host_id = f.host_id
   and f.month::timestamp >= h.valid_from
   and f.month::timestamp < coalesce(h.valid_to, '9999-12-31'::timestamp)
),

-- Aggregate by neighbourhood + month
by_grp as (
  select
    listing_neighbourhood,
    month,
    100.0 * sum(case when j.is_active then 1 else 0 end)::numeric / nullif(count(*),0) as active_listings_rate,
    min(j.avg_price) filter (where j.is_active) as min_price_active,
    max(j.avg_price) filter (where j.is_active) as max_price_active,
    percentile_disc(0.5) within group (order by j.avg_price) filter (where j.is_active) as median_price_active,
    avg(j.avg_price) filter (where j.is_active) as average_price_active,
    count(distinct j.host_id) as distinct_hosts,
    100.0 * count(distinct case when j.host_is_superhost then j.host_id end)
           / nullif(count(distinct j.host_id),0) as superhost_rate,
    avg(j.avg_review_score) filter (where j.is_active) as avg_review_scores_rating_active,
    sum(case when j.is_active then 1 else 0 end) as active_cnt,
    sum(case when not j.is_active then 1 else 0 end) as inactive_cnt,
    sum(j.stays) as total_stays,
    avg(j.est_revenue) filter (where j.is_active) as avg_estimated_revenue_per_active_listings
  from j
  where listing_neighbourhood is not null
  group by 1,2
),

pct as (
  select
    *,
    lag(active_cnt)   over (partition by listing_neighbourhood order by month) as prev_active_cnt,
    lag(inactive_cnt) over (partition by listing_neighbourhood order by month) as prev_inactive_cnt
  from by_grp
)

select
  listing_neighbourhood,
  month,
  active_listings_rate,
  min_price_active,
  max_price_active,
  median_price_active,
  average_price_active,
  distinct_hosts,
  superhost_rate,
  avg_review_scores_rating_active,
  total_stays,
  avg_estimated_revenue_per_active_listings,
  active_cnt,
  inactive_cnt,
  case
    when coalesce(prev_active_cnt,0) = 0 then 0
    else 100.0 * (active_cnt - prev_active_cnt)::numeric / prev_active_cnt
  end as pct_change_active_listings,
  case
    when coalesce(prev_inactive_cnt,0) = 0 then 0
    else 100.0 * (inactive_cnt - prev_inactive_cnt)::numeric / prev_inactive_cnt
  end as pct_change_inactive_listings
from pct
order by listing_neighbourhood, month
