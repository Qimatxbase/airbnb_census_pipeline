{{ config(
  schema='silver',
  alias='fact_listing',
  materialized='view'
) }}

with src as (
  select
    cast(nullif(trim(listing_id), '') as bigint) as listing_id,
    cast(nullif(trim(host_id), '') as bigint)    as host_id,
    case
      when lower(coalesce(trim(has_availability), '')) in ('t','true','1','y','yes') then true
      else false
    end as is_active,
    cast(nullif(trim(availability_30), '') as int) as availability_30,
    cast(nullif(regexp_replace(coalesce(trim(price), ''), '[^0-9\.]', '', 'g'), '') as numeric(12,2)) as price,
    cast(nullif(trim(review_scores_rating), '') as numeric(6,2)) as review_scores_rating,
    source_month
  from {{ ref('bronze_airbnb_raw') }}
  where nullif(trim(listing_id), '') is not null
    and nullif(trim(host_id), '')   is not null
),

by_month as (
  select
    listing_id,
    host_id,
    source_month as month,
    bool_or(is_active)                   as is_active,
    max(availability_30)                 as availability_30,
    avg(price)                           as avg_price,
    avg(review_scores_rating)            as avg_review_score,
    case when bool_or(is_active) then (30 - max(availability_30)) else 0 end                                 as stays,
    case when bool_or(is_active) then ((30 - max(availability_30))::numeric * avg(price)) else 0::numeric end as est_revenue
  from src
  group by 1,2,3
)

select *
from by_month
