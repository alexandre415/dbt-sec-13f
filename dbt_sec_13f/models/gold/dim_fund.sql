-- models/gold/dim_fund.sql
-- One row per unique fund (filing manager).
-- Deduplicates across quarters — keeps most recent filing data per fund.

{{ config(materialized='table', schema='gold') }}

with filers as (
    select
        accession_number,
        fund_name,
        report_date,
        is_amendment,
        filing_period,
        row_number() over (
            partition by fund_name
            order by report_date desc
        ) as rn
    from {{ ref('stg_13f_filers') }}
    where fund_name is not null
)

select
    md5(fund_name)   as fund_sk,
    fund_name,
    accession_number as latest_accession_number,
    report_date      as latest_report_date,
    filing_period    as latest_filing_period
from filers
where rn = 1