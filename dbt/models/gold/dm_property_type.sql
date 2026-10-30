{{ config(schema='gold', alias='dm_property_type', materialized='view') }}

with f as (
  select * from {{ ref('fact_listing') }}
),
p as (
  select * from {{ ref('property_history') }}
),
j as (
  select
    coalesce(p.property_type, 'unknown') as property_type,
    coalesce(p.room_type, 'unknown')     as room_type,
    coalesce(p.accommodates, 0)          as accommodates,
    f.month,
    f.listing_id,
    f.host_id,
    f.is_active,
    f.avg_price,
    f.stays,
    f.est_revenue,
    f.avg_review_score
  from f
  left join p
    on p.listing_id = f.listing_id
   and f.month >= p.valid_from
   and f.month::timestamp < coalesce(p.valid_to, '9999-12-31'::timestamp)
),
by_grp as (
  select
    property_type, room_type, accommodates, month,
    100.0 * sum(case when j.is_active then 1 else 0 end)::numeric / nullif(count(*), 0) as active_listings_rate,
    min(nullif(j.avg_price, 0)) filter (where j.is_active) as min_price_active,
    max(nullif(j.avg_price, 0)) filter (where j.is_active) as max_price_active,
    percentile_disc(0.5) within group (order by nullif(j.avg_price, 0)) filter (where j.is_active) as median_price_active,
    avg(nullif(j.avg_price, 0)) filter (where j.is_active) as average_price_active,
    count(distinct j.host_id) as distinct_hosts,
    100.0 * count(distinct case when h.host_is_superhost then j.host_id end) / nullif(count(distinct j.host_id), 0) as superhost_rate,
    avg(j.avg_review_score) filter (where j.is_active) as avg_review_scores_rating_active,
    sum(case when j.is_active then 1 else 0 end) as active_cnt,
    sum(case when not j.is_active then 1 else 0 end) as inactive_cnt,
    sum(j.stays) as total_stays,
    avg(j.est_revenue) filter (where j.is_active) as avg_estimated_revenue_per_active_listings
  from j
  left join {{ ref('host_history') }} h
    on h.host_id = j.host_id
   and j.month >= h.valid_from
   and j.month::timestamp < coalesce(h.valid_to, '9999-12-31'::timestamp)
  group by 1,2,3,4
),
with_prev as (
  select
    *,
    lag(active_cnt)   over (partition by property_type, room_type, accommodates order by month) as prev_active_cnt,
    lag(inactive_cnt) over (partition by property_type, room_type, accommodates order by month) as prev_inactive_cnt
  from by_grp
)
select
  property_type, room_type, accommodates, month,
  active_listings_rate,
  min_price_active, max_price_active, median_price_active, average_price_active,
  distinct_hosts, superhost_rate,
  avg_review_scores_rating_active,
  total_stays, avg_estimated_revenue_per_active_listings,
  active_cnt, inactive_cnt,
  case
    when prev_active_cnt is null then null
    when prev_active_cnt = 0 and active_cnt = 0 then 0
    when prev_active_cnt = 0 and active_cnt > 0  then 100
    else 100.0 * (active_cnt - prev_active_cnt)::numeric / prev_active_cnt
  end as pct_change_active_listings,
  case
    when prev_inactive_cnt is null then null
    when prev_inactive_cnt = 0 and inactive_cnt = 0 then 0
    when prev_inactive_cnt = 0 and inactive_cnt > 0  then 100
    else 100.0 * (inactive_cnt - prev_inactive_cnt)::numeric / prev_inactive_cnt
  end as pct_change_inactive_listings
from with_prev
order by property_type, room_type, accommodates, month
