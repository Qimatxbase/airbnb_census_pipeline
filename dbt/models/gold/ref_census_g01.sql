{{ config(schema='gold', alias='ref_census_g01', materialized='table') }}

with base as (
  select
    trim(lga_code)  as lga_code,
    payload,
    source_file,
    loaded_at
  from {{ ref('bronze_census_g01_raw') }}
  where nullif(trim(lga_code), '') is not null
),

joined as (
  select
    b.lga_code,
    l.lga_name,
    b.payload,
    b.source_file,
    b.loaded_at
  from base b
  left join {{ ref('dim_lga') }} l
    on b.lga_code = l.lga_code
)

select * from joined
