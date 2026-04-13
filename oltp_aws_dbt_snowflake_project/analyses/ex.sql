{% set min_id = 100 %}
select * from {{ ref('bronze_bookings') }}
where listing_id > {{min_id}} 
order by listing_id desc