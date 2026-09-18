-- ============================================================
-- Demand Forecast Override Analysis
-- SQL Queries (run against forecast_supply_chain_data table)
-- ============================================================

-- ------------------------------------------------------------
-- Query 1: Overall MAPE by category (System vs Final forecast)
-- ------------------------------------------------------------
SELECT
    category,
    ROUND(AVG(ABS(system_forecast - actual_demand) * 1.0 / actual_demand) * 100, 2) AS system_mape_pct,
    ROUND(AVG(ABS(final_forecast - actual_demand) * 1.0 / actual_demand) * 100, 2) AS final_mape_pct
FROM forecast_supply_chain_data
GROUP BY category
ORDER BY category;


-- ------------------------------------------------------------
-- Query 2: Bias direction (overridden rows only)
-- Positive = over-forecasting, Negative = under-forecasting
-- ------------------------------------------------------------
SELECT
    category,
    warehouse,
    ROUND(AVG((final_forecast - actual_demand) * 1.0 / actual_demand) * 100, 2) AS avg_bias_pct
FROM forecast_supply_chain_data
WHERE override_flag = 1 OR CAST(override_flag AS TEXT) = 'True'
GROUP BY category, warehouse
ORDER BY avg_bias_pct DESC;


-- ------------------------------------------------------------
-- Query 3: Worst-offender SKU/warehouse combinations
-- Ranked by the accuracy gap caused by manual overrides
-- ------------------------------------------------------------
SELECT
    sku_id,
    warehouse,
    category,
    COUNT(*) AS months_overridden,
    ROUND(AVG(ABS(final_forecast - actual_demand) * 1.0 / actual_demand) * 100, 2) AS override_mape_pct,
    ROUND(AVG(ABS(system_forecast - actual_demand) * 1.0 / actual_demand) * 100, 2) AS system_mape_pct
FROM forecast_supply_chain_data
WHERE override_flag = 1 OR CAST(override_flag AS TEXT) = 'True'
GROUP BY sku_id, warehouse, category
HAVING months_overridden >= 3
ORDER BY (override_mape_pct - system_mape_pct) DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Query 4: Override rate vs forecast accuracy
-- Feeds the CORREL() calculation in Excel
-- ------------------------------------------------------------
SELECT
    sku_id,
    warehouse,
    ROUND(AVG(CASE WHEN override_flag = 1
                    OR CAST(override_flag AS TEXT) = 'True'
               THEN 1.0 ELSE 0.0 END) * 100, 1) AS override_rate_pct,
    ROUND(AVG(ABS(final_forecast - actual_demand) * 1.0 / actual_demand) * 100, 2) AS final_mape_pct
FROM forecast_supply_chain_data
GROUP BY sku_id, warehouse
ORDER BY override_rate_pct DESC;


-- ------------------------------------------------------------
-- Query 5: Estimated excess inventory carrying cost
-- Assumes a 15% annual carrying-cost rate (refined further in Excel)
-- ------------------------------------------------------------
SELECT
    category,
    warehouse,
    ROUND(SUM(ABS(final_forecast - system_forecast) * unit_cost * 0.15), 0)
        AS estimated_excess_carrying_cost_inr
FROM forecast_supply_chain_data
WHERE (override_flag = 1 OR CAST(override_flag AS TEXT) = 'True')
  AND final_forecast > system_forecast
GROUP BY category, warehouse
ORDER BY estimated_excess_carrying_cost_inr DESC;
