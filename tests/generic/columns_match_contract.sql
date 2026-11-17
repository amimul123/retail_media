
{% test columns_match_contract(model, source_table) %}
select e.table_name, e.column_name as missing_column
from {{ ref('expected_raw_schema') }} e
where e.table_name = '{{ source_table }}'
  and not exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'raw'
        and c.table_name = e.table_name
        and lower(c.column_name) = lower(e.column_name)
  )
{% endtest %}
