{{ config(schema='silver', materialized='table') }}

-- Monthly observation intervals, rebuilt from complete source history.
-- SQL history models are not dbt snapshot runs or exact change timestamps.
select
  host_id,
  host_is_superhost,
  source_month as valid_from,
  lead(source_month) over (partition by host_id order by source_month) as valid_to
from {{ ref('dim_host_base') }}
