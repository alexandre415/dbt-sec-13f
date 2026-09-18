-- models/gold/dim_security.sql
-- One row per unique security (CUSIP).
-- Deduplicates by keeping the most recent name for each CUSIP.

{{ config(materialized='table', schema='gold') }}

with securities as (
    select
        cusip,
        issuer_name,
        title_of_class,
        figi,
        row_number() over (
            partition by cusip
            order by _loaded_at desc
        ) as rn
    from {{ ref('stg_13f_positions') }}
    where cusip is not null
)

select
    cusip                   as security_sk,
    cusip,
    issuer_name,
    title_of_class,
    figi
from securities
where rn = 1