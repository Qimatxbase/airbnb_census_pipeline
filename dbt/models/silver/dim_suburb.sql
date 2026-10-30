-- Silver conformed: map listing/host suburbs to LGA (deterministic)
{{ config(schema='silver', alias='dim_suburb', materialized='view') }}

with src as (  -- standardized input from base
  select
    cast(listing_id as bigint)                                as listing_id,
    nullif(trim(listing_neighbourhood),'')                    as listing_neighbourhood,
    nullif(trim(host_neighbourhood),'')                       as host_neighbourhood,
    lower(trim(listing_neighbourhood))                        as listing_key,
    lower(trim(host_neighbourhood))                           as host_key,
    source_month,
    valid_ts
  from {{ ref('dim_suburb_base') }}
),

-- Deduplicate suburb to LGA mapping to avoid multi-match
map_listing as (
  select
    lower(trim(suburb_name)) as suburb_key,
    min(trim(lga_name))      as lga_name
  from {{ ref('bronze_lga_suburb_raw') }}
  where nullif(trim(suburb_name),'') is not null
  group by 1
),
map_host as (
  select
    lower(trim(suburb_name)) as suburb_key,
    min(trim(lga_name))      as lga_name
  from {{ ref('bronze_lga_suburb_raw') }}
  where nullif(trim(suburb_name),'') is not null
  group by 1
),

-- Bring LGA code for both sides
lga_code as (
  select
    lower(trim(lga_name)) as lga_name_key,
    nullif(trim(lga_code),'') as lga_code,
    nullif(trim(lga_name),'') as lga_name
  from {{ ref('bronze_lga_code_raw') }}
  where nullif(trim(lga_code),'') is not null
    and nullif(trim(lga_name),'') is not null
)

select
  s.listing_id,
  s.listing_neighbourhood,
  s.host_neighbourhood,

  -- listing-side mapping
  lc_list.lga_name  as listing_lga_name,
  lc_list.lga_code  as listing_lga_code,

  -- Host location is mapped independently from listing location.
  lc_host.lga_name as host_lga_name,
  lc_host.lga_code as host_lga_code,

  s.source_month,
  s.valid_ts
from src s
left join map_listing ml
  on ml.suburb_key = s.listing_key
left join lga_code lc_list
  on lc_list.lga_name_key = lower(trim(ml.lga_name))
left join map_host mh
  on mh.suburb_key = s.host_key
left join lga_code lc_host
  on lc_host.lga_name_key = lower(trim(mh.lga_name))
