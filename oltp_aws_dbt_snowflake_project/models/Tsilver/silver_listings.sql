{{
  config(
    materialized="incremental",
    unique_key='LISTING_ID'
  )
}}

select
    *,
    {{ tag('price_per_night') }} as price_per_night_tag
from {{ ref('bronze_listings') }}

{% if is_incremental() %}
  where created_at > (select coalesce(max(created_at), '1900-01-01') from {{ this }})
{% endif %}

