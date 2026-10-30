{{ config(alias='airbnb') }}
select * from {{ source('raw', 'airbnb_raw') }}
