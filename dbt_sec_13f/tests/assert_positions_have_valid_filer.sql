-- tests/assert_positions_have_valid_filer.sql
--
-- Singular test (custom business rule):
-- Every position in fato_positions must have a matching filer in dim_fund.
-- This catches data integrity issues where a position was loaded
-- without a corresponding COVERPAGE record.
--
-- Returns rows that FAIL the test (dbt expects 0 rows = test passes).

select
    f.accession_number,
    f.fund_sk,
    count(*) as orphaned_positions
from {{ ref('fato_positions') }} f
left join {{ ref('dim_fund') }} d
    on f.fund_sk = d.fund_sk
where d.fund_sk is null
group by 1, 2
having count(*) > 0