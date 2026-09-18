-- models/gold/fato_positions.sql
-- Fact table: one row per fund-security-quarter position.
-- Joins Silver positions to dimensions via surrogate keys.
-- This is the table BI tools (Power BI, etc.) query directly.

{{ config(materialized='table', schema='gold') }}

with positions as (
    select
        p.accession_number,
        p.position_sk,
        p.cusip,
        p.issuer_name,
        p.market_value_thousands,
        p.shares_or_principal_amount,
        p.amount_type,
        p.put_call,
        p.filing_period,
        p._loaded_at,
        f.fund_name,
        f.report_date
    from {{ ref('stg_13f_positions') }} p
    inner join {{ ref('stg_13f_filers') }} f
        on p.accession_number = f.accession_number
)
select
    -- surrogate key for this fact row
    md5(p.accession_number || '|' || p.position_sk::string) as position_fact_sk,

    -- foreign keys to dimensions
    md5(p.fund_name)    as fund_sk,
    p.cusip             as security_sk,
    p.report_date       as date_sk,

    -- degenerate dimensions (kept on the fact for filtering)
    p.accession_number,
    p.amount_type,
    p.put_call,
    p.filing_period,

    -- measures
    p.market_value_thousands,
    p.shares_or_principal_amount,
    p.market_value_thousands * 1000 as market_value_usd,

    p._loaded_at
from positions p