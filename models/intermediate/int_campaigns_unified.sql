{# Union of all conformed campaign sources listed in var campaign_source_models. New source = new model + one list entry. #}
{% for m in var('campaign_source_models') %}
select * from {{ ref(m) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}
