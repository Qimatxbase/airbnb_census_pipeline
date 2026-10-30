{{ config(alias='census_g01') }}
select * from {{ source('raw', 'census_g01_raw') }}