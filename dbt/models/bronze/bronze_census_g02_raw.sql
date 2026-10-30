{{ config(alias='census_g02') }}
select * from {{ source('raw', 'census_g02_raw') }}