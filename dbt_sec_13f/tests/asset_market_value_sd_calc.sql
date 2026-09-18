-- tests/assert_market_value_usd_calculation.sql
--
-- Singular test (custom business rule):
-- market_value_usd must always equal market_value_thousands * 1000.
-- This validates that the derived measure in the fact table
-- was not corrupted during transformation.
--
-- Returns rows that FAIL the test (dbt expects 0 rows = test passes).

select
    position_fact_sk,
    market_value_thousands,
    market_value_usd,
    market_value_thousands * 1000 as expected_market_value_usd
from {{ ref('fato_positions') }}
where market_value_usd != market_value_thousands * 1000
  and market_value_usd is not null
  and market_value_thousands is not null