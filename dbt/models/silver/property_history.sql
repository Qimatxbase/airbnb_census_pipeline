{{ config(schema='silver', materialized='table') }}

select
  listing_id,
  property_type,
  room_type,
  accommodates,
  source_month as valid_from,
  lead(source_month) over (partition by listing_id order by source_month) as valid_to
from {{ ref('dim_property_base') }}
