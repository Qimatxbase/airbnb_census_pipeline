{{ config(schema='silver', materialized='table') }}

select
  cast(nullif(trim(listing_id), '') as bigint) as listing_id,
  nullif(trim(property_type), '') as property_type,
  nullif(trim(room_type), '') as room_type,
  coalesce(cast(nullif(trim(accommodates), '') as int), 0) as accommodates,
  source_month,
  source_observed_at as valid_ts
from {{ ref('bronze_airbnb_raw') }}
where nullif(trim(listing_id), '') is not null
