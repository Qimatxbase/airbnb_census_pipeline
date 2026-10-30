{{ config(schema='silver', alias='dim_lga', materialized='table') }}
select distinct
  nullif(trim(lga_code), '') as lga_code,
  nullif(trim(lga_name), '') as lga_name
from {{ ref('bronze_lga_code_raw') }}
where nullif(trim(lga_code), '') is not null
  and nullif(trim(lga_name), '') is not null