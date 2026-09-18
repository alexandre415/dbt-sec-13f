-- models/gold/dim_date.sql
-- One row per reporting quarter present in the dataset.

{{ config(materialized='table', schema='gold') }}

select 
    report_date as date_sk,
    report_date,
    year(report_date)  as report_year,
    quarter(report_date) as report_quarter,
    'Q' || quarter(report_date) || '-' || year(report_date) as quarter_label,
    filing_period
from {{ ref('stg_13f_filers') }}
where report_date is not null
qualify row_number() over (partition by report_date order by filing_period desc) = 1
order by report_date