{{config(materialized='incremental',unique_key='HOST_ID')}}
select HOST_ID,
replace(HOST_NAME,' ','_') as HOST_NAME,
host_since,
is_superhost,
response_rate,
created_at
from {{ref('bronze_host')}}

{% if is_incremental() %}
  where created_at > (select coalesce(max(created_at), '1900-01-01') from {{ this }})
{% endif %}

