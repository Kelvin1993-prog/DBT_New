{% macro learn_variables() %}

    {% set your_name_jinja = "Kelvin" %}

    {{ log("hello " ~ your_name_jinja, info=True)}}

    {{ log("Hello dbt user "~ var("user_name", "No USERNAME IS SET") ~ "!", info=True)}}

{% endmacro %}