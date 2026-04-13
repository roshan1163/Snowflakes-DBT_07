{{
  config(
    materialized="incremental",
    unique_key='BOOKING_ID'
  )
}}

select
    BOOKING_ID,
    LISTING_ID,
    BOOKING_DATE,
    {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }} as TOTAL_BOOKING_AMOUNT,
    BOOKING_STATUS,
    CREATED_AT
from {{ ref('bronze_bookings') }}

{% if is_incremental() %}
  where CREATED_AT > (select coalesce(max(CREATED_AT), '1900-01-01') from {{ this }})
{% endif %}