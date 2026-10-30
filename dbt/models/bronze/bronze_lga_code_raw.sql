{{ config(alias='nsw_lga_code') }}
select * from {{ source('raw', 'nsw_lga_code_raw') }}