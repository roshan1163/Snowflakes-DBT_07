{% set configg = [
 {
    "table": ref('silver_bookings'),
    "alias": "bk"
 },
 {
    "table": ref('silver_listings'),
    "alias": "ls",
    "join_condition": "bk.listing_id = ls.listing_id",
    "exclude": "exclude (listing_id, created_at)"
 },
 {
    "table": ref('silver_hosts'),
    "alias": "hs",
    "join_condition": "ls.host_id = hs.host_id",
    "exclude": "exclude (host_id, created_at)"
 }
] %}

select
    {%- for item in configg %}
    {{ item.alias }}.* {{ item.exclude if item.exclude is defined else '' }} {{ "," if not loop.last }}
    {%- endfor %}
from {{ configg[0].table }} as {{ configg[0].alias }}
{% for item in configg[1:] %}
left join {{ item.table }} as {{ item.alias }}
    on {{ item.join_condition }}
{% endfor %}
