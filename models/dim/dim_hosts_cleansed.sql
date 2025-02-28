
{{
  config(
    materialized = 'view',
    )
}}


WITH src__hosts AS (
    SELECT * FROM {{ ref('src_hosts') }}
)

SELECT
    host_id,
    NVL(host_name, 'Anonymous') As host_name,
    is_superhost,
    created_at,
    updated_at
FROM src__hosts
