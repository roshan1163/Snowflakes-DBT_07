{{
    config(
        materialized='incremental'
    )
}}

select * from {{ ref('bronze_bookings') }}

{% if is_incremental() %}

  -- This where clause is automatically injected by dbt only when the table already exists!
  where CREATED_AT > (select max(CREATED_AT) from {{ this }})

{% endif %}