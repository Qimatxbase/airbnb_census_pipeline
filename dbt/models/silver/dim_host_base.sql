{{ config(schema='silver', materialized='table') }}

-- Hosts may appear on several listings. Resolve each source month deterministically.
with ranked as (
  select
    cast(nullif(trim(host_id), '') as bigint) as host_id,
    lower(coalesce(trim(host_is_superhost), '')) in ('t','true','1','y','yes') as host_is_superhost,
    source_month,
    source_observed_at as valid_ts,
    row_number() over (
      partition by cast(nullif(trim(host_id), '') as bigint), source_month
      order by source_observed_at desc, cast(listing_id as bigint)
    ) as rn
  from {{ ref('bronze_airbnb_raw') }}
  where nullif(trim(host_id), '') is not null
)
select host_id, host_is_superhost, source_month, valid_ts
from ranked where rn = 1
