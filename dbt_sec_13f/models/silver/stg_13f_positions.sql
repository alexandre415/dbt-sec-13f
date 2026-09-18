-- models/silver/stg_13f_positions.sql
--
-- Silver layer: extracts and types the raw INFOTABLE Bronze data.
-- One row per fund-security-quarter position.
-- No business logic here — only cleaning, typing, and renaming.
--
-- on_schema_change='fail': if the Bronze table schema changes unexpectedly,
-- this model breaks loudly instead of silently corrupting the Silver layer.

{{ config(
    materialized='view',
    schema='silver'
) }}

with source as (
    select
        accession_number,
        infotable_sk,
        nameofissuer,
        titleofclass,
        cusip,
        figi,
        value,
        sshprnamt,
        sshprnamttype,
        putcall,
        _source_file,
        _loaded_at
    from {{ source('bronze', 'raw_13f_infotable') }}
    where accession_number != 'ACCESSION_NUMBER'  -- remove any stray header rows
),

typed as (
    select
        accession_number,
        infotable_sk::NUMBER(38,0)      as position_sk,
        upper(trim(nameofissuer))       as issuer_name,
        upper(trim(titleofclass))       as title_of_class,
        upper(trim(cusip))              as cusip,
        nullif(trim(figi), '')          as figi,
        try_to_number(value)            as market_value_thousands,
        try_to_number(sshprnamt)        as shares_or_principal_amount,
        upper(trim(sshprnamttype))      as amount_type,       -- SH = shares, PRN = principal
        nullif(upper(trim(putcall)), '') as put_call,          -- NULL for regular equity positions
        _source_file,
        _loaded_at,
        -- derive the reporting quarter from the source file path
        -- path format: .../01sep2025-30nov2025/INFOTABLE.tsv
        regexp_substr(_source_file, '[0-9]{2}[a-z]{3}[0-9]{4}-[0-9]{2}[a-z]{3}[0-9]{4}') as filing_period
    from source
    where try_to_number(value) >= 0   -- remove positions with negative market value (data quality)
      and cusip is not null
      and cusip != ''
)

select * from typed