select listing_id, month, count(*) as row_count
from {{ ref('fact_listing') }}
group by listing_id, month
having count(*) > 1
