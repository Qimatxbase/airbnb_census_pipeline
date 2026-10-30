{{ config(schema='silver', alias='dim_suburb_base', materialized='table') }}

select
  cast(nullif(trim(listing_id), '') as bigint)           as listing_id,
  nullif(trim(listing_neighbourhood), '')                as listing_neighbourhood,
  nullif(trim(host_neighbourhood), '')                   as host_neighbourhood,
  source_month,
  source_observed_at                                    as valid_ts
from {{ ref('bronze_airbnb_raw') }}
where nullif(trim(listing_id), '') is not null
