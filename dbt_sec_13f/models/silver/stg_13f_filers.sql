-- models/silver/stg_13f_filers.sql
--
-- Silver layer: extracts and types the raw COVERPAGE Bronze data.
-- One row per fund (filer) per quarter.
-- Links to stg_13f_positions via accession_number.

{{ config(
    materialized='view',
    schema='silver'
) }}

with source as (
    select
        accession_number,
        reportcalendarorquarter,
        isamendment,
        amendmentno,
        amendmenttype,
        confdeniedexpired,
        datedeniedexpired,
        datereported,
        reasonfornonconfidentiality,
        filingmanager_name,
        _source_file,
        _loaded_at
    from {{ source('bronze', 'raw_13f_coverpage') }}
    where accession_number != 'ACCESSION_NUMBER'  -- remove any stray header rows
),

typed as (
    select
        accession_number,
        upper(trim(filingmanager_name))             as fund_name,
        -- reportcalendarorquarter comes as '30-SEP-2025' — convert to a proper date
        try_to_date(reportcalendarorquarter, 'DD-MON-YYYY') as report_date,
        case when upper(isamendment) = 'Y' then true else false end as is_amendment,
        nullif(trim(amendmentno), '')               as amendment_no,
        nullif(trim(amendmenttype), '')             as amendment_type,
        nullif(trim(datereported), '')              as date_reported,
        _source_file,
        _loaded_at,
        regexp_substr(_source_file, '[0-9]{2}[a-z]{3}[0-9]{4}-[0-9]{2}[a-z]{3}[0-9]{4}') as filing_period
    from source
    where filingmanager_name is not null
      and filingmanager_name != ''
)

select * from typed