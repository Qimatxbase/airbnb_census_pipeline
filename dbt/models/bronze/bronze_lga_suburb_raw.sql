{{ config(alias='nsw_lga_suburb') }}
select * from {{ source('raw', 'nsw_lga_suburb_raw') }}