select 'host' as entity, cast(host_id as text) as entity_id, valid_from, valid_to
from {{ ref('host_history') }}
where valid_to <= valid_from
union all
select 'property', cast(listing_id as text), valid_from, valid_to
from {{ ref('property_history') }}
where valid_to <= valid_from
