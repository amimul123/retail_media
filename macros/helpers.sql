
{# ---------------- text cleaning ---------------- #}

{# trim + turn placeholder strings that manual sources contain into NULL #}
{% macro clean_text(col) -%}
case 
    when lower(trim({{ col }})) in ('', 'null', 'none', 'n/a', 'na', 'nan', '#n/a', '-') then null 
    else trim({{ col }}) end
{%- endmacro %}

{# ids exported as floats ("36.0") -> "36" #}
{% macro clean_id(col) -%}
regexp_replace({{ clean_text(col) }}, '\.0+$', '')
{%- endmacro %}

{# join key for names: lower-case, whitespace collapsed #}
{% macro name_key(col) -%}
lower(regexp_replace(trim({{ col }}), '\s+', ' ', 'g'))
{%- endmacro %}

{% macro normalize_gender(col) -%}
case
    when lower(trim({{ col }})) in ('female', 'f', 'woman', 'women', 'w', 'weiblich','girls') then 'Female'
    when lower(trim({{ col }})) in ('male', 'm', 'man', 'men', 'männlich','boys') then 'Male'
    when lower(trim({{ col }})) in ('kids') then 'Kids'
    when lower(trim({{ col }})) in ('babys') then 'Babys'
    when lower(trim({{ col }})) in ('unisex') then 'Unisex'
    when lower(trim({{ col }})) in ('all', 'both', 'any') then 'All'
    else 'Unknown'
end
{%- endmacro %}


{# ---------------- typing ---------------- #}

{# PostgreSQL-safe integer conversion #}
{% macro safe_cast(expr, type) -%}
    {% if type | lower == 'bigint' %}
        case
            when ({{ expr }}) ~ '^[+-]?[0-9]+$' then cast(({{ expr }}) as bigint)
            else null
        end
    {% elif type | lower == 'integer' or type | lower == 'int' %}
        case
            when ({{ expr }}) ~ '^[+-]?[0-9]+$' then cast(({{ expr }}) as integer)
            else null
        end
    {% elif type | lower in ['double', 'float', 'double precision'] %}
        case
            when nullif(trim(({{ expr }})::text), '') is not null
                    and trim(({{ expr }})::text)
                        ~ '^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$'
            then cast(({{ expr }}) as double precision)
            else null
        end
    {% elif type | lower == 'timestamp' %}
        case
            when nullif(trim(({{ expr }})::text), '') is null then null
            when trim(({{ expr }})::text) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then cast(({{ expr }}) as timestamp)
            else null
        end
    {% else %}
        cast(({{ expr }}) as {{ type }})
    {% endif %}
{%- endmacro %}


{# accepts 01.09.2022, 2022-09-01 and 01/09/2022 #}
{% macro parse_date(col) -%}
case
    when trim({{ col }}) ~ '^[0-9]{2}\.[0-9]{2}\.[0-9]{4}$'
        then to_date(trim({{ col }}), 'DD.MM.YYYY')
    when trim({{ col }}) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        then cast(trim({{ col }}) as date)
    when trim({{ col }}) ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        then to_date(trim({{ col }}), 'DD/MM/YYYY')
    else null
end
{%- endmacro %}


{# "1,362" / "1 362" -> 1362 #}
{% macro parse_int(col) -%}
case
    when replace(replace(trim({{ col }}), ',', ''), ' ', '')
         ~ '^[+-]?[0-9]+$'
    then cast(
        replace(replace(trim({{ col }}), ',', ''), ' ', '')
        as bigint
    )
    else null
end
{%- endmacro %}


{# percentage conversion #}
{% macro parse_percent(col) -%}
case
    when position('%' in {{ col }}) > 0
        and replace(replace(trim({{ col }}), '%', ''), ',', '.')
            ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'
    then cast(
        replace(replace(trim({{ col }}), '%', ''), ',', '.')
        as double precision
    ) / 100.0

    when replace(trim({{ col }}), ',', '.')
         ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'
    then cast(
        replace(trim({{ col }}), ',', '.')
        as double precision
    )

    else null
end
{%- endmacro %}


{# ---------------- math / keys ---------------- #}

{% macro safe_divide(n, d) -%}
(cast({{ n }} as double precision) / nullif({{ d }}, 0))
{%- endmacro %}

{% macro surrogate_hash(expr) -%}
md5({{ expr }})
{%- endmacro %}

{# naive UTC-ish timestamp -> business date in the reporting timezone #}
{% macro to_local_date(ts_col, source_tz=none, target_tz=none) -%}
cast((({{ ts_col }}) at time zone '{{ source_tz or var("tracking_timezone") }}')
     at time zone '{{ target_tz or var("reporting_timezone") }}' as date)
{%- endmacro %}

{#
  Stable campaign key.
  teaser -> CMS id, online_placement -> normalised name. 
#}
{% macro campaign_key(type_col, id_col, name_key_col) -%}
md5(coalesce({{ type_col }}, 'unknown') || '|' || coalesce(
    case
    {%- for ctype, strategy in var('natural_key_strategy').items() %}
        when {{ type_col }} = '{{ ctype }}' then
            {%- if strategy == 'id' %} coalesce({{ id_col }}, {{ name_key_col }})
            {%- else %} coalesce({{ name_key_col }}, {{ id_col }}){%- endif %}
    {%- endfor %}
        else coalesce({{ id_col }}, {{ name_key_col }})
    end, 'unknown'))
{%- endmacro %}

{# ---------------- incremental window (backfill-friendly) ---------------- #}
{#
  Normal run : [max(date in this) - lookback_days, +inf)
  Backfill   : dbt build --vars '{reprocess_start_date: 2025-06-01, reprocess_end_date: 2025-06-07}'
  First run  : [min_event_date, +inf)

#}
{% macro window_start(date_col='event_date') -%}
{%- if var('reprocess_start_date', none) is not none -%}
cast('{{ var("reprocess_start_date") }}' as date)
{%- elif is_incremental() -%}
(select coalesce(max({{ date_col }}), cast('{{ var("min_event_date") }}' as date)) - {{ var('lookback_days') }} from {{ this }})
{%- else -%}
cast('{{ var("min_event_date") }}' as date)
{%- endif -%}
{%- endmacro %}

{% macro window_end() -%}
{%- if var('reprocess_end_date', none) is not none -%}
cast('{{ var("reprocess_end_date") }}' as date)
{%- else -%}
cast('2999-12-31' as date)
{%- endif -%}
{%- endmacro %}
