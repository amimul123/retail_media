{# Returns rows where the expression is not true (NULL counts as failing). Works at model or column level. #}
{% test expression_is_true(model, expression, column_name=none) %}
select *
from {{ model }}
where not coalesce(({{ expression }}), false)
{% endtest %}
