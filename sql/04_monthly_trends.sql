-- =========================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 04: MONTHLY KPI TRENDS
-- BUSINESS: NexaDistribution (Synthetic)
-- =========================================================
--
-- PURPOSE:
-- Analyze supply chain performance across
-- all 12 reporting months.
--
-- REPORTING PERIOD:
-- November 2025 to October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE DATA GRAIN:
-- One SKU x One Warehouse x One Month
--
-- OUTPUT DATA GRAIN:
-- One row per reporting month
--
-- DOCUMENTATION PLAN:
-- 04.1 Monthly Aggregation and Validation
-- 04.2 Consolidated 10-KPI Scorecard
-- 04.3 Month-over-Month Analysis
-- 04.4 Historical Reconciliation
--
-- IMPORTANT:
-- Do not manually hardcode results for 12 months.
-- All calculations must use the imported data.
-- =========================================================


-- =========================================================
-- SECTION 04.1: MONTHLY AGGREGATION & VALIDATION
-- =========================================================
--
-- BUSINESS QUESTION:
-- How much demand was received and fulfilled
-- in each reporting month?
--
-- VALIDATION OBJECTIVES:
-- 1. Confirm all 12 months are present.
-- 2. Confirm 360 SKU-warehouse records per month.
-- 3. Confirm 120 SKUs and 3 warehouses per month.
-- 4. Verify monthly demand reconciliation.
-- 5. Calculate monthly Fill Rate.
-- 6. Confirm October matches KPI 01.
--
-- FILL RATE FORMULA:
-- SUM(Fulfilled Units) / SUM(Demand Units) * 100
--
-- Note:
-- The ratio is calculated from monthly totals,
-- not by averaging individual row-level rates.
-- =========================================================

SELECT

    DATE_FORMAT(
        i.reporting_month, '%Y-%m'
    ) AS reporting_month,

    COUNT(*) AS inventory_locations,

    COUNT(DISTINCT i.sku_id)
        AS distinct_skus,

    COUNT(DISTINCT i.warehouse)
        AS distinct_warehouses,

    SUM(i.demand_units)
        AS total_demand_units,

    SUM(i.fulfilled_units)
        AS total_fulfilled_units,

    SUM(
        i.demand_units - i.fulfilled_units
    ) AS recalculated_unfulfilled_units,

    SUM(i.unfulfilled_units)
        AS stored_unfulfilled_units,

    ROUND(
        SUM(i.fulfilled_units) * 100.0
        / NULLIF(SUM(i.demand_units), 0),
        2
    ) AS fill_rate_pct

FROM supply_chain_ai_db.inventory AS i

GROUP BY i.reporting_month

ORDER BY i.reporting_month;
-- =========================================================
-- SECTION 04.1: VERIFIED MONTHLY AGGREGATION RESULTS
-- =========================================================
--
-- Reporting Period: November 2025 - October 2026
-- Reporting Months: 12
-- Locations Per Month: 360
-- Distinct SKUs Per Month: 120
-- Distinct Warehouses Per Month: 3
-- Total Inventory Records: 4320
--
-- DATA VALIDATION:
-- Stored and recalculated unfulfilled demand totals
-- matched in every reporting month.
--
-- OCTOBER 2026 RECONCILIATION:
-- Demand Units      : 51603
-- Fulfilled Units   : 47922
-- Unfulfilled Units : 3681
-- Fill Rate         : 92.87%
--
-- HISTORICAL OBSERVATIONS:
-- Highest Fill Rate : Nov 2025 - 99.33%
-- Lowest Fill Rate  : Sep 2026 - 92.09%
-- October Fill Rate : 92.87%
--
-- Sep-to-Oct Change:
-- 92.87 - 92.09 = +0.78 percentage points
--
-- INTERPRETATION:
-- October showed a modest improvement in Fill Rate
-- compared with September. Historical variation
-- requires warehouse, supplier and SKU investigation.
--
-- LIMITATION:
-- These aggregated results describe performance;
-- they do not establish causes for changes.
--
-- VALIDATION STATUS: PASSED
-- =========================================================
-- =========================================================
-- SECTION 04.2: CONSOLIDATED MONTHLY KPI SCORECARD
-- =========================================================
--
-- BUSINESS QUESTION:
-- How did our ten core supply chain KPIs perform
-- across all 12 reporting months?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT GRAIN:
-- One row per reporting month
--
-- METHOD:
-- 1. Aggregate KPI inputs by reporting month.
-- 2. Apply the ten validated KPI formulas.
-- 3. Preserve correct numerator/denominator logic.
-- 4. Compare October with our KPI 01-10 results.
--
-- IMPORTANT:
-- Supplier OTD and average lead time use their
-- respective eligible delivery-line denominators.
--
-- Inventory value and at-risk locations represent
-- individual month-end snapshots.
--
-- Turnover is calculated for each month separately.
-- =========================================================

WITH monthly_base AS (

    SELECT

        reporting_month,

        COUNT(*) AS total_locations,

        -- KPI 01: Fill Rate inputs
        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        -- KPI 02: Stockout locations
        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        -- KPI 03: At-risk locations
        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        -- KPI 04: Eligible supplier deliveries
        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_deliveries,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_deliveries,

        -- KPI 05: Eligible lead-time deliveries
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_time_deliveries,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN replenishment_lead_time_days
                     * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days,

        -- KPI 06: Month-end inventory valuation
        SUM(closing_stock_units * unit_cost)
            AS closing_inventory_value_inr,

        -- KPI 07: Portfolio inventory coverage
        SUM(closing_stock_units)
            AS total_closing_units,

        SUM(
            demand_units * 1.0 /
            NULLIF(days_in_month, 0)
        ) AS estimated_daily_demand,

        -- KPI 08: Monthly inventory turnover
        SUM(opening_stock_units * unit_cost)
            AS opening_inventory_value_inr,

        SUM(fulfilled_units * unit_cost)
            AS fulfilled_cogs_proxy_inr,

        -- KPI 09: Unfulfilled demand
        SUM(demand_units - fulfilled_units)
            AS total_unfulfilled_units,

        -- KPI 10: Potential gross-margin exposure
        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost, 0
            )
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    GROUP BY reporting_month

)

SELECT

    DATE_FORMAT(
        reporting_month, '%Y-%m'
    ) AS reporting_month,

    total_locations,

    -- KPI 01
    ROUND(
        total_fulfilled_units * 100.0 /
        NULLIF(total_demand_units, 0), 2
    ) AS fill_rate_pct,

    -- KPI 02
    ROUND(
        stockout_locations * 100.0 /
        NULLIF(total_locations, 0), 2
    ) AS stockout_rate_pct,

    -- KPI 03
    at_risk_locations,

    -- Supporting KPI 03 percentage
    ROUND(
        at_risk_locations * 100.0 /
        NULLIF(total_locations, 0), 2
    ) AS at_risk_rate_pct,

    -- KPI 04
    ROUND(
        on_time_deliveries * 100.0 /
        NULLIF(eligible_otd_deliveries, 0), 2
    ) AS supplier_otd_pct,

    -- KPI 05
    ROUND(
        weighted_lead_days /
        NULLIF(eligible_lead_time_deliveries, 0), 2
    ) AS avg_supplier_lead_time_days,

    -- KPI 06
    ROUND(
        closing_inventory_value_inr, 2
    ) AS closing_inventory_value_inr,

    -- KPI 07
    ROUND(
        total_closing_units /
        NULLIF(estimated_daily_demand, 0), 2
    ) AS inventory_coverage_days,

    -- KPI 08
    ROUND(
        fulfilled_cogs_proxy_inr /
        NULLIF(
            (
                opening_inventory_value_inr
                + closing_inventory_value_inr
            ) / 2.0,
            0
        ), 2
    ) AS monthly_turnover_times,

    -- KPI 09
    total_unfulfilled_units,

    -- Supporting KPI 09 percentage
    ROUND(
        total_unfulfilled_units * 100.0 /
        NULLIF(total_demand_units, 0), 2
    ) AS unfulfilled_demand_rate_pct,

    -- KPI 10
    ROUND(
        potential_margin_exposure_inr, 2
    ) AS potential_margin_exposure_inr

FROM monthly_base

ORDER BY reporting_month;
-- =========================================================
-- SECTION 04.2: VERIFIED MONTHLY KPI SCORECARD
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT GRAIN:
-- One row per reporting month
--
-- EXECUTION RESULTS:
-- Reporting Months           : 12
-- Inventory Locations/Month  : 360
-- Core KPIs Calculated       : 10 per month
-- Total Core KPI Results     : 120
--
-- OCTOBER 2026 RECONCILIATION:
--
-- KPI 01 Fill Rate              : 92.87%
-- KPI 02 Stockout Rate          : 21.94%
-- KPI 03 At-Risk Locations      : 141
--        At-Risk Rate           : 39.17%
-- KPI 04 Supplier OTD           : 88.61%
-- KPI 05 Average Lead Time      : 10.86 days
-- KPI 06 Closing Inventory      : 58027088.73 INR
-- KPI 07 Inventory Coverage     : 19.13 days
-- KPI 08 Monthly Turnover       : 1.45 times
-- KPI 09 Unfulfilled Demand     : 3681 units
--        Unfulfilled Rate       : 7.13%
-- KPI 10 Gross-Margin Exposure  : 3071205.83 INR
--
-- VALIDATION RESULT:
-- All ten October KPIs match the individually
-- verified values from 03_business_kpis.sql.
--
-- HISTORICAL OBSERVATIONS:
--
-- Highest Fill Rate:
-- Nov 2025 = 99.33%
--
-- Lowest Fill Rate:
-- Sep 2026 = 92.09%
--
-- Highest Stockout Rate:
-- Jan 2026 = 22.22%
--
-- Lowest Stockout Rate:
-- Nov 2025 = 4.44%
--
-- Highest At-Risk Locations:
-- Nov 2025 = 189
--
-- Lowest At-Risk Locations:
-- May 2026 = 114
--
-- Highest Supplier OTD:
-- Aug 2026 = 90.40%
--
-- Lowest Supplier OTD:
-- Jun 2026 = 87.11%
--
-- Highest Closing Inventory Value:
-- May 2026 = 73555013.25 INR
--
-- Lowest Closing Inventory Value:
-- Dec 2025 = 57753788.18 INR
--
-- Highest Potential Gross-Margin Exposure:
-- Sep 2026 = 4154178.34 INR
--
-- Lowest Potential Gross-Margin Exposure:
-- Nov 2025 = 252835.20 INR
--
-- SEPTEMBER TO OCTOBER COMPARISON:
--
-- Fill Rate:
-- 92.87 - 92.09 = +0.78 percentage points
--
-- Stockout Rate:
-- 21.94 - 18.89 = +3.05 percentage points
--
-- At-Risk Locations:
-- 141 - 134 = +7 locations
--
-- Unfulfilled Demand:
-- 3681 - 4192 = -511 units
--
-- Potential Gross-Margin Exposure:
-- 3071205.83 - 4154178.34
-- = -1082972.51 INR (-26.07%)
--
-- BUSINESS INTERPRETATION:
-- October Fill Rate improved relative to September,
-- while stockout occurrence became more widespread.
--
-- This is possible because the two KPIs measure
-- different aspects of inventory availability.
--
-- October also showed reduced unfulfilled units
-- and lower estimated gross-margin exposure.
--
-- Investigation is needed to determine which
-- SKUs and warehouses explain these movements.
--
-- IMPORTANT AGGREGATION RULES:
-- 1. Percentage KPIs use ratios of summed inputs.
-- 2. Supplier OTD excludes unknown outcomes.
-- 3. Lead time uses delivery-line weighting.
-- 4. Inventory value is a month-end snapshot.
-- 5. Turnover is measured separately per month.
-- 6. Margin exposure is a potential opportunity,
--    not confirmed lost profit.
-- 7. Monthly ratios must not be blindly averaged
--    or summed for annual reporting.
--
-- LIMITATIONS:
-- 1. All results represent synthetic business data.
-- 2. Historical patterns do not prove causality.
-- 3. November's unusually high Fill Rate and
--    At-Risk Rate combination needs investigation.
-- 4. Individual historical months have not yet
--    been independently reconciled to Python.
-- 5. No external performance benchmarks have
--    been applied.
--
-- VALIDATION STATUS:
-- 12 monthly result rows returned successfully.
-- October 2026 reconciled to all ten core KPIs.
-- Full 12-month independent QA remains pending.
-- =========================================================
-- =========================================================
-- SECTION 04.3A: MONTH-OVER-MONTH FILL RATE ANALYSIS
-- =========================================================
--
-- BUSINESS QUESTION:
-- How did the customer demand Fill Rate change
-- compared with the previous reporting month?
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- OUTPUT GRAIN:
-- One row per reporting month
--
-- KPI FORMULA:
-- Fill Rate (%) =
-- SUM(fulfilled_units) / SUM(demand_units) * 100
--
-- MOM FORMULA:
-- Fill Rate Change (percentage points) =
-- Current Month Fill Rate - Previous Month Fill Rate
--
-- SQL METHOD:
-- 1. Aggregate demand and fulfillment by month.
-- 2. Calculate each month's Fill Rate.
-- 3. Use LAG() to retrieve the previous month's rate.
-- 4. Calculate the percentage-point change.
-- 5. Classify performance movement.
--
-- IMPORTANT:
-- The first reporting month has no previous month.
-- Its MoM comparison must therefore remain NULL.
--
-- Calculations retain full intermediate precision
-- and are rounded only in the final output.
-- =========================================================

WITH monthly_totals AS (

    SELECT

        reporting_month,

        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units

    FROM supply_chain_ai_db.inventory

    GROUP BY reporting_month

),

monthly_rates AS (

    SELECT

        reporting_month,

        total_demand_units,

        total_fulfilled_units,

        total_fulfilled_units * 100.0 /
        NULLIF(total_demand_units, 0)
            AS fill_rate_pct

    FROM monthly_totals

),

monthly_comparison AS (

    SELECT

        reporting_month,

        total_demand_units,

        total_fulfilled_units,

        fill_rate_pct,

        LAG(fill_rate_pct, 1)
        OVER (
            ORDER BY reporting_month
        ) AS previous_fill_rate_pct

    FROM monthly_rates

)

SELECT

    DATE_FORMAT(
        reporting_month, '%Y-%m'
    ) AS reporting_month,

    total_demand_units,

    total_fulfilled_units,

    ROUND(fill_rate_pct, 2)
        AS current_fill_rate_pct,

    ROUND(previous_fill_rate_pct, 2)
        AS previous_fill_rate_pct,

    ROUND(
        fill_rate_pct - previous_fill_rate_pct,
        2
    ) AS fill_rate_mom_change_pp,

    CASE

        WHEN previous_fill_rate_pct IS NULL
        THEN 'First Month'

        WHEN fill_rate_pct > previous_fill_rate_pct
        THEN 'Improved'

        WHEN fill_rate_pct < previous_fill_rate_pct
        THEN 'Deteriorated'

        ELSE 'Unchanged'

    END AS performance_movement

FROM monthly_comparison

ORDER BY reporting_month;
-- =========================================================
-- SECTION 04.3A: VERIFIED FILL RATE MOM RESULTS
-- =========================================================
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- BUSINESS QUESTION:
-- How did Fill Rate change from month to month?
--
-- KPI DEFINITION:
-- Fill Rate (%) =
-- SUM(fulfilled_units) / SUM(demand_units) * 100
--
-- MOM DEFINITION:
-- Current Unrounded Fill Rate
-- minus Previous Unrounded Fill Rate
--
-- REPORTING UNIT:
-- Percentage points (pp)
--
-- VALIDATION SUMMARY:
-- Reporting Months          : 12
-- Valid MoM Comparisons      : 11
-- First Month Without Prior : 1
-- Months Improved           : 5
-- Months Deteriorated       : 6
-- Months Unchanged          : 0
--
-- VERIFIED RESULTS:
--
-- Month    Fill Rate    MoM Change    Movement
-- 2025-11   99.33%       NULL         First Month
-- 2025-12   94.96%      -4.37 pp      Deteriorated
-- 2026-01   92.74%      -2.22 pp      Deteriorated
-- 2026-02   93.99%      +1.26 pp      Improved
-- 2026-03   92.24%      -1.75 pp      Deteriorated
-- 2026-04   92.91%      +0.66 pp      Improved
-- 2026-05   93.38%      +0.47 pp      Improved
-- 2026-06   93.04%      -0.34 pp      Deteriorated
-- 2026-07   94.76%      +1.71 pp      Improved
-- 2026-08   93.07%      -1.68 pp      Deteriorated
-- 2026-09   92.09%      -0.98 pp      Deteriorated
-- 2026-10   92.87%      +0.77 pp      Improved
--
-- MAXIMUM IMPROVEMENT:
-- July 2026: +1.71 percentage points
--
-- MAXIMUM DETERIORATION:
-- December 2025: -4.37 percentage points
--
-- OCTOBER 2026 CALCULATION:
--
-- September Fill Rate =
-- 48834 / 53026 * 100
-- = approximately 92.09444%
--
-- October Fill Rate =
-- 47922 / 51603 * 100
-- = approximately 92.86669%
--
-- October MoM Change =
-- 92.86669 - 92.09444
-- = approximately +0.77 percentage points
--
-- IMPORTANT ROUNDING RULE:
-- MoM calculations use unrounded KPI values.
-- ROUND() is applied only to final output values.
--
-- Subtracting displayed values:
-- 92.87 - 92.09 = 0.78
--
-- This differs slightly from the correctly
-- calculated +0.77 pp due to intermediate rounding.
--
-- BUSINESS INTERPRETATION:
-- October Fill Rate improved relative to September.
--
-- However, improvement followed consecutive
-- deterioration in August and September.
--
-- Further analysis is required to investigate
-- warehouse, SKU and supplier-level performance.
--
-- LIMITATIONS:
-- 1. MoM changes do not establish root causes.
-- 2. The first month has no prior-period comparison.
-- 3. Aggregate improvement can conceal SKU shortages.
-- 4. Results describe a synthetic business scenario.
--
-- VALIDATION STATUS:
-- All 12 results verified against monthly totals.
-- LAG() and movement classifications validated.
-- =========================================================
-- =========================================================
-- SECTION 04.3B: CONSOLIDATED MONTH-OVER-MONTH ANALYSIS
-- =========================================================
--
-- BUSINESS QUESTION:
-- How did the remaining nine core supply chain KPIs
-- change compared with the preceding month?
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT GRAIN:
-- One row per reporting month
--
-- METHOD:
-- 1. Aggregate source values by reporting month.
-- 2. Calculate unrounded monthly KPI values.
-- 3. Retrieve previous-month KPIs using LAG().
-- 4. Calculate absolute and relative movements.
-- 5. Round only in the final SELECT.
--
-- IMPORTANT RULES:
-- - Rate changes are measured in percentage points.
-- - Financial and unit quantities use absolute change
--   and, when appropriate, relative percentage change.
-- - First-month comparisons remain NULL.
-- - Percentage changes from a zero previous value
--   remain NULL because the denominator is zero.
-- - Inventory valuations are month-end snapshots.
-- =========================================================

WITH monthly_base AS (

    SELECT

        reporting_month,

        COUNT(*) AS total_locations,

        -- KPI 02: Stockout Rate
        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        -- KPI 03: At-Risk Inventory
        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        -- KPI 04: Supplier OTD
        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_deliveries,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_deliveries,

        -- KPI 05: Supplier Lead Time
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_time_deliveries,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NOT NULL
                THEN replenishment_lead_time_days
                     * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days,

        -- KPI 06: Closing Inventory Value
        SUM(closing_stock_units * unit_cost)
            AS closing_inventory_value_inr,

        -- KPI 07: Inventory Coverage
        SUM(closing_stock_units)
            AS total_closing_units,

        SUM(
            demand_units * 1.0 /
            NULLIF(days_in_month, 0)
        ) AS estimated_daily_demand,

        -- KPI 08: Monthly Inventory Turnover
        SUM(opening_stock_units * unit_cost)
            AS opening_inventory_value_inr,

        SUM(fulfilled_units * unit_cost)
            AS fulfilled_cogs_proxy_inr,

        -- KPI 09: Unfulfilled Demand
        SUM(demand_units - fulfilled_units)
            AS unfulfilled_units,

        -- KPI 10: Gross-Margin Exposure
        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost, 0
            )
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    GROUP BY reporting_month

),

monthly_kpis AS (

    SELECT

        reporting_month,

        -- KPI 02
        stockout_locations * 100.0 /
        NULLIF(total_locations, 0)
            AS stockout_rate_pct,

        -- KPI 03
        at_risk_locations,

        at_risk_locations * 100.0 /
        NULLIF(total_locations, 0)
            AS at_risk_rate_pct,

        -- KPI 04
        on_time_deliveries * 100.0 /
        NULLIF(eligible_otd_deliveries, 0)
            AS supplier_otd_pct,

        -- KPI 05
        weighted_lead_days /
        NULLIF(eligible_lead_time_deliveries, 0)
            AS avg_lead_time_days,

        -- KPI 06
        closing_inventory_value_inr,

        -- KPI 07
        total_closing_units /
        NULLIF(estimated_daily_demand, 0)
            AS inventory_coverage_days,

        -- KPI 08
        fulfilled_cogs_proxy_inr /
        NULLIF(
            (
                opening_inventory_value_inr
                + closing_inventory_value_inr
            ) / 2.0,
            0
        ) AS monthly_turnover_times,

        -- KPI 09
        unfulfilled_units,

        -- KPI 10
        potential_margin_exposure_inr

    FROM monthly_base

),

previous_month AS (

    SELECT

        reporting_month,

        stockout_rate_pct,

        LAG(stockout_rate_pct)
        OVER (ORDER BY reporting_month)
            AS prev_stockout_rate_pct,

        at_risk_locations,

        LAG(at_risk_locations)
        OVER (ORDER BY reporting_month)
            AS prev_at_risk_locations,

        at_risk_rate_pct,

        LAG(at_risk_rate_pct)
        OVER (ORDER BY reporting_month)
            AS prev_at_risk_rate_pct,

        supplier_otd_pct,

        LAG(supplier_otd_pct)
        OVER (ORDER BY reporting_month)
            AS prev_supplier_otd_pct,

        avg_lead_time_days,

        LAG(avg_lead_time_days)
        OVER (ORDER BY reporting_month)
            AS prev_lead_time_days,

        closing_inventory_value_inr,

        LAG(closing_inventory_value_inr)
        OVER (ORDER BY reporting_month)
            AS prev_inventory_value_inr,

        inventory_coverage_days,

        LAG(inventory_coverage_days)
        OVER (ORDER BY reporting_month)
            AS prev_inventory_coverage_days,

        monthly_turnover_times,

        LAG(monthly_turnover_times)
        OVER (ORDER BY reporting_month)
            AS prev_monthly_turnover_times,

        unfulfilled_units,

        LAG(unfulfilled_units)
        OVER (ORDER BY reporting_month)
            AS prev_unfulfilled_units,

        potential_margin_exposure_inr,

        LAG(potential_margin_exposure_inr)
        OVER (ORDER BY reporting_month)
            AS prev_margin_exposure_inr

    FROM monthly_kpis

)

SELECT

    DATE_FORMAT(
        reporting_month, '%Y-%m'
    ) AS reporting_month,

    -- KPI 02: Stockout Rate MoM
    ROUND(
        stockout_rate_pct - prev_stockout_rate_pct,
        2
    ) AS stockout_mom_change_pp,

    -- KPI 03: At-Risk Location Count MoM
    at_risk_locations - prev_at_risk_locations
        AS at_risk_locations_mom_change,

    -- KPI 03: At-Risk Rate MoM
    ROUND(
        at_risk_rate_pct - prev_at_risk_rate_pct,
        2
    ) AS at_risk_rate_mom_change_pp,

    -- KPI 04: Supplier OTD MoM
    ROUND(
        supplier_otd_pct - prev_supplier_otd_pct,
        2
    ) AS supplier_otd_mom_change_pp,

    -- KPI 05: Average Lead Time MoM
    ROUND(
        avg_lead_time_days - prev_lead_time_days,
        2
    ) AS lead_time_mom_change_days,

    -- KPI 06: Closing Inventory Value - INR Change
    ROUND(
        closing_inventory_value_inr
        - prev_inventory_value_inr,
        2
    ) AS inventory_value_mom_change_inr,

    -- KPI 06: Closing Inventory Value - % Change
    ROUND(
        (
            closing_inventory_value_inr
            - prev_inventory_value_inr
        ) * 100.0 /
        NULLIF(prev_inventory_value_inr, 0),
        2
    ) AS inventory_value_mom_change_pct,

    -- KPI 07: Inventory Coverage MoM
    ROUND(
        inventory_coverage_days
        - prev_inventory_coverage_days,
        2
    ) AS coverage_mom_change_days,

    -- KPI 08: Monthly Inventory Turnover MoM
    ROUND(
        monthly_turnover_times
        - prev_monthly_turnover_times,
        2
    ) AS turnover_mom_change_times,

    -- KPI 09: Unfulfilled Demand - Units Change
    unfulfilled_units - prev_unfulfilled_units
        AS unfulfilled_units_mom_change,

    -- KPI 09: Unfulfilled Demand - % Change
    ROUND(
        (
            unfulfilled_units - prev_unfulfilled_units
        ) * 100.0 /
        NULLIF(prev_unfulfilled_units, 0),
        2
    ) AS unfulfilled_units_mom_change_pct,

    -- KPI 10: Gross-Margin Exposure - INR Change
    ROUND(
        potential_margin_exposure_inr
        - prev_margin_exposure_inr,
        2
    ) AS margin_exposure_mom_change_inr,

    -- KPI 10: Gross-Margin Exposure - % Change
    ROUND(
        (
            potential_margin_exposure_inr
            - prev_margin_exposure_inr
        ) * 100.0 /
        NULLIF(prev_margin_exposure_inr, 0),
        2
    ) AS margin_exposure_mom_change_pct

FROM previous_month

ORDER BY reporting_month;
-- =========================================================
-- SECTION 04.3B: VERIFIED CONSOLIDATED MOM ANALYSIS
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- REPORTING GRAIN:
-- One row per reporting month
--
-- EXECUTION RESULTS:
-- Reporting Months          : 12
-- MoM Comparison Months     : 11
-- MoM Measures              : 13
-- First Month MoM Values    : NULL
--
-- VALIDATION:
-- Monthly comparisons reconcile with the
-- previously verified monthly KPI scorecard.
--
-- All changes were calculated using unrounded
-- underlying KPI values.
--
-- OCTOBER 2026 VERIFIED MOM RESULTS:
--
-- Stockout Rate Change       : +3.06 pp
-- At-Risk Locations Change   : +7
-- At-Risk Rate Change        : +1.94 pp
-- Supplier OTD Change        : -0.03 pp
-- Average Lead Time Change   : -0.22 days
--
-- Inventory Value Change     : -6977238.68 INR
-- Inventory Value Change (%) : -10.73%
--
-- Inventory Coverage Change  : -1.21 days
-- Inventory Turnover Change  : +0.03 times
--
-- Unfulfilled Demand Change  : -511 units
-- Unfulfilled Demand (%)     : -12.19%
--
-- Potential Margin Exposure
-- Absolute Change            : -1082972.51 INR
-- Percentage Change          : -26.07%
--
-- OCTOBER MATHEMATICAL VERIFICATION:
--
-- Stockout Rate Change =
-- (79 - 68) / 360 * 100
-- = +3.06 percentage points
--
-- At-Risk Location Change =
-- 141 - 134
-- = +7 locations
--
-- At-Risk Rate Change =
-- 7 / 360 * 100
-- = +1.94 percentage points
--
-- Unfulfilled Demand Change =
-- 3681 - 4192
-- = -511 units
--
-- Unfulfilled Demand Percentage Change =
-- -511 / 4192 * 100
-- = -12.19%
--
-- Closing Inventory Value Change =
-- 58027088.73 - 65004327.41
-- = -6977238.68 INR
--
-- Closing Inventory Value Percentage Change =
-- -6977238.68 / 65004327.41 * 100
-- = -10.73%
--
-- Potential Gross-Margin Exposure Change =
-- 3071205.83 - 4154178.34
-- = -1082972.51 INR
--
-- Margin Exposure Percentage Change =
-- -1082972.51 / 4154178.34 * 100
-- = -26.07%
--
-- HISTORICAL OBSERVATIONS:
--
-- Largest Stockout Rate Increase:
-- December 2025 = +13.89 pp
--
-- Largest Stockout Rate Decrease:
-- February 2026 = -2.50 pp
--
-- Largest Supplier OTD Improvement:
-- August 2026 = +2.74 pp
--
-- Largest Supplier OTD Deterioration:
-- June 2026 = -2.91 pp
--
-- Largest Inventory Value Increase:
-- February 2026 = +10.72%
--
-- Largest Inventory Value Decline:
-- October 2026 = -10.73%
--
-- Largest Increase in Unfulfilled Demand:
-- December 2025 = +2457 units
--
-- Largest Decrease in Unfulfilled Demand:
-- July 2026 = -928 units
--
-- Largest Percentage Increase in Margin Exposure:
-- December 2025 = +1041.69%
--
-- Largest Percentage Decline in Margin Exposure:
-- October 2026 = -26.07%
--
-- BUSINESS INTERPRETATION:
--
-- October showed improving unit fulfillment and
-- lower estimated margin exposure relative to
-- September.
--
-- However, stockout occurrence and the number
-- of positive-stock at-risk locations increased.
--
-- Closing inventory value and estimated coverage
-- declined, suggesting the need for SKU-level
-- and warehouse-level availability analysis.
--
-- The contrasting KPI movements require
-- investigation before causal explanations
-- or replenishment recommendations are made.
--
-- IMPORTANT CALCULATION RULES:
--
-- 1. Rate changes are reported in percentage points.
-- 2. Financial values include INR and % changes.
-- 3. Quantity values include unit movements.
-- 4. Unrounded KPI values are used for all MoM math.
-- 5. ROUND() is applied only in final output.
-- 6. First-month comparisons remain NULL.
-- 7. Division by zero is handled using NULLIF().
-- 8. Negative movements are not automatically
--    favorable or unfavorable across all metrics.
--
-- LIMITATIONS:
--
-- 1. All results use synthetic business data.
-- 2. MoM comparisons do not establish causality.
-- 3. Large percentage changes may reflect small
--    previous-month denominators.
-- 4. Monthly aggregation hides individual SKU events.
-- 5. Margin exposure is not confirmed lost profit.
-- 6. Independent Python reconciliation is pending.
--
-- VALIDATION STATUS:
-- Section 04.3B outputs checked against the
-- established 12-month KPI scorecard.
--
-- Independent source-level QA remains pending.
-- =========================================================
-- =========================================================
-- SECTION 04.4: HISTORICAL RECONCILIATION & FINAL QA
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- PURPOSE:
-- Verify monthly completeness, location uniqueness,
-- business integrity and consistency of derived
-- analytical fields across the entire dataset.
--
-- OUTPUT:
-- Vertical Metric | Value validation report
--
-- VALIDATION LEVEL:
-- Database-level historical reconciliation.
--
-- IMPORTANT:
-- This does not replace the independent
-- SQL-Python reconciliation planned for Script 09.
-- =========================================================

WITH monthly_audit AS (

    SELECT

        i.reporting_month,

        COUNT(*) AS record_count,

        COUNT(DISTINCT i.sku_id)
            AS sku_count,

        COUNT(DISTINCT i.warehouse)
            AS warehouse_count,

        COUNT(DISTINCT i.sku_id, i.warehouse)
            AS unique_sku_warehouse_pairs,

        -- 1. Missing dimension keys
        SUM(
            CASE
                WHEN i.sku_id IS NULL
                  OR i.warehouse IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_key_records,

        -- 2. Invalid demand or fulfillment
        SUM(
            CASE
                WHEN i.demand_units IS NULL
                  OR i.fulfilled_units IS NULL
                  OR i.demand_units < 0
                  OR i.fulfilled_units < 0
                  OR i.fulfilled_units > i.demand_units
                THEN 1 ELSE 0
            END
        ) AS invalid_demand_records,

        -- 3. Stored vs recalculated unfulfilled units
        SUM(
            CASE
                WHEN i.unfulfilled_units IS NULL
                  OR i.demand_units IS NULL
                  OR i.fulfilled_units IS NULL
                  OR i.unfulfilled_units <>
                     (i.demand_units - i.fulfilled_units)
                THEN 1 ELSE 0
            END
        ) AS unfulfilled_mismatches,

        -- 4. Invalid opening or closing stock
        SUM(
            CASE
                WHEN i.opening_stock_units IS NULL
                  OR i.closing_stock_units IS NULL
                  OR i.opening_stock_units < 0
                  OR i.closing_stock_units < 0
                THEN 1 ELSE 0
            END
        ) AS invalid_stock_records,

        -- 5. Closing inventory value reconciliation
        SUM(
            CASE
                WHEN i.closing_inventory_value IS NULL
                  OR i.closing_stock_units IS NULL
                  OR i.unit_cost IS NULL
                  OR ABS(
                      i.closing_inventory_value
                      - (i.closing_stock_units * i.unit_cost)
                  ) > 0.01
                THEN 1 ELSE 0
            END
        ) AS closing_value_mismatches,

        -- 6. Fulfilled COGS proxy reconciliation
        SUM(
            CASE
                WHEN i.fulfilled_cogs_proxy IS NULL
                  OR i.fulfilled_units IS NULL
                  OR i.unit_cost IS NULL
                  OR ABS(
                      i.fulfilled_cogs_proxy
                      - (i.fulfilled_units * i.unit_cost)
                  ) > 0.01
                THEN 1 ELSE 0
            END
        ) AS cogs_proxy_mismatches,

        -- 7. Potential margin exposure reconciliation
        SUM(
            CASE
                WHEN i.potential_margin_exposure IS NULL
                  OR i.demand_units IS NULL
                  OR i.fulfilled_units IS NULL
                  OR i.unit_selling_price IS NULL
                  OR i.unit_cost IS NULL
                  OR ABS(
                      i.potential_margin_exposure
                      - (
                          (i.demand_units - i.fulfilled_units)
                          * GREATEST(
                              i.unit_selling_price
                              - i.unit_cost,
                              0
                          )
                      )
                  ) > 0.01
                THEN 1 ELSE 0
            END
        ) AS margin_exposure_mismatches,

        -- 8. Calendar-day validation
        SUM(
            CASE
                WHEN i.reporting_month IS NULL
                  OR i.days_in_month IS NULL
                  OR i.days_in_month <>
                     DAY(LAST_DAY(i.reporting_month))
                THEN 1 ELSE 0
            END
        ) AS invalid_month_day_records,

        -- 9. Supplier delivery-count validation
        SUM(
            CASE
                WHEN i.supplier_deliveries_count IS NULL
                  OR i.supplier_deliveries_count < 0
                  OR i.supplier_on_time_deliveries_count < 0
                  OR i.supplier_on_time_deliveries_count >
                     i.supplier_deliveries_count
                THEN 1 ELSE 0
            END
        ) AS invalid_delivery_records,

        -- 10. Stockout-day validation
        SUM(
            CASE
                WHEN i.stockout_days IS NULL
                  OR i.stockout_days < 0
                  OR i.stockout_days > i.days_in_month
                THEN 1 ELSE 0
            END
        ) AS invalid_stockout_day_records

    FROM supply_chain_ai_db.inventory AS i

    GROUP BY i.reporting_month

),

ordered_audit AS (

    SELECT

        monthly_audit.*,

        LAG(reporting_month)
        OVER (
            ORDER BY reporting_month
        ) AS previous_month

    FROM monthly_audit

),

final_audit AS (

    SELECT

        ordered_audit.*,

        CASE
            WHEN reporting_month IS NULL
              OR DAY(reporting_month) <> 1
              OR record_count <> 360
              OR sku_count <> 120
              OR warehouse_count <> 3
              OR unique_sku_warehouse_pairs <> 360
              OR missing_key_records > 0
              OR invalid_demand_records > 0
              OR unfulfilled_mismatches > 0
              OR invalid_stock_records > 0
              OR closing_value_mismatches > 0
              OR cogs_proxy_mismatches > 0
              OR margin_exposure_mismatches > 0
              OR invalid_month_day_records > 0
              OR invalid_delivery_records > 0
              OR invalid_stockout_day_records > 0
              OR (
                  previous_month IS NOT NULL
                  AND TIMESTAMPDIFF(
                      MONTH,
                      previous_month,
                      reporting_month
                  ) <> 1
              )
            THEN 1
            ELSE 0
        END AS month_has_issue

    FROM ordered_audit

)

SELECT metric, value

FROM (

    SELECT 1 AS sort_order,
           'Reporting Months Found' AS metric,
           CAST(COUNT(*) AS CHAR) AS value
    FROM final_audit

    UNION ALL

    SELECT 2, 'First Reporting Month',
           DATE_FORMAT(MIN(reporting_month), '%Y-%m')
    FROM final_audit

    UNION ALL

    SELECT 3, 'Last Reporting Month',
           DATE_FORMAT(MAX(reporting_month), '%Y-%m')
    FROM final_audit

    UNION ALL

    SELECT 4, 'Total Inventory Records',
           CAST(SUM(record_count) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 5, 'Months Without 360 Records',
           CAST(SUM(record_count <> 360) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 6, 'Months Without 120 SKUs',
           CAST(SUM(sku_count <> 120) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 7, 'Months Without 3 Warehouses',
           CAST(SUM(warehouse_count <> 3) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 8, 'Months Without 360 Unique SKU-Warehouse Pairs',
           CAST(
               SUM(unique_sku_warehouse_pairs <> 360)
               AS CHAR
           )
    FROM final_audit

    UNION ALL

    SELECT 9, 'Missing or Invalid Dimension Keys',
           CAST(SUM(missing_key_records) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 10, 'Invalid Demand or Fulfillment Records',
           CAST(SUM(invalid_demand_records) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 11, 'Unfulfilled Demand Calculation Mismatches',
           CAST(SUM(unfulfilled_mismatches) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 12, 'Invalid Opening or Closing Stock Records',
           CAST(SUM(invalid_stock_records) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 13, 'Closing Inventory Value Mismatches',
           CAST(SUM(closing_value_mismatches) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 14, 'Fulfilled COGS Proxy Mismatches',
           CAST(SUM(cogs_proxy_mismatches) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 15, 'Potential Margin Exposure Mismatches',
           CAST(SUM(margin_exposure_mismatches) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 16, 'Invalid Days-in-Month Records',
           CAST(SUM(invalid_month_day_records) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 17, 'Invalid Supplier Delivery Records',
           CAST(SUM(invalid_delivery_records) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 18, 'Invalid Stockout-Day Records',
           CAST(SUM(invalid_stockout_day_records) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 19, 'Missing Monthly Transitions',
           CAST(
               SUM(
                   CASE
                       WHEN previous_month IS NOT NULL
                        AND TIMESTAMPDIFF(
                            MONTH,
                            previous_month,
                            reporting_month
                        ) <> 1
                       THEN 1 ELSE 0
                   END
               ) AS CHAR
           )
    FROM final_audit

    UNION ALL

    SELECT 20, 'Months With Any QA Failure',
           CAST(SUM(month_has_issue) AS CHAR)
    FROM final_audit

    UNION ALL

    SELECT 21, 'Overall Historical QA Status',

           CASE
               WHEN COUNT(*) = 12
                AND MIN(reporting_month) = '2025-11-01'
                AND MAX(reporting_month) = '2026-10-01'
                AND SUM(record_count) = 4320
                AND SUM(month_has_issue) = 0
               THEN 'PASS'
               ELSE 'FAIL'
           END

    FROM final_audit

) AS qa_results

ORDER BY sort_order;
-- =========================================================
-- SECTION 04.4: VERIFIED HISTORICAL QA RESULTS
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- VALIDATION SCOPE:
-- Database-level monthly completeness,
-- data integrity and derived-field reconciliation.
--
-- EXECUTION STATUS: PASS
--
-- =========================================================
-- A. REPORTING PERIOD VALIDATION
-- =========================================================
--
-- Reporting Months Found         : 12
-- First Reporting Month          : 2025-11
-- Last Reporting Month           : 2026-10
-- Total Inventory Records        : 4320
--
-- Months Without 360 Records     : 0
-- Months Without 120 SKUs        : 0
-- Months Without 3 Warehouses    : 0
-- Months Without 360 Unique
-- SKU-Warehouse Pairs            : 0
--
-- INTERPRETATION:
-- The database contains the expected monthly
-- SKU-warehouse reporting structure.
--
-- =========================================================
-- B. DATA QUALITY VALIDATION
-- =========================================================
--
-- Missing or Invalid
-- Dimension Keys                 : 0
--
-- Invalid Demand or
-- Fulfillment Records            : 0
--
-- Invalid Opening or
-- Closing Stock Records          : 0
--
-- Invalid Days-in-Month Records  : 0
--
-- Invalid Supplier
-- Delivery Records               : 0
--
-- Invalid Stockout-Day Records   : 0
--
-- INTERPRETATION:
-- No violations were identified by these
-- specific database-level validation rules.
--
-- =========================================================
-- C. DERIVED KPI RECONCILIATION
-- =========================================================
--
-- Unfulfilled Demand
-- Calculation Mismatches         : 0
--
-- Closing Inventory Value
-- Mismatches                     : 0
--
-- Fulfilled COGS Proxy
-- Mismatches                     : 0
--
-- Potential Margin Exposure
-- Mismatches                     : 0
--
-- VALIDATED FORMULAS:
--
-- Unfulfilled Units =
-- Demand Units - Fulfilled Units
--
-- Closing Inventory Value =
-- Closing Stock Units * Unit Cost
--
-- Fulfilled COGS Proxy =
-- Fulfilled Units * Unit Cost
--
-- Potential Margin Exposure =
-- Unfulfilled Units *
-- GREATEST(Unit Selling Price - Unit Cost, 0)
--
-- FINANCIAL VALIDATION TOLERANCE:
-- 0.01 INR per record
--
-- INTERPRETATION:
-- The stored derived values agree with
-- their SQL recalculations within tolerance.
--
-- =========================================================
-- D. MONTHLY CONTINUITY VALIDATION
-- =========================================================
--
-- Missing Monthly Transitions    : 0
-- Months With Any QA Failure     : 0
--
-- Overall Historical QA Status   : PASS
--
-- =========================================================
-- E. COMPLETED SCRIPT 04 CHECKPOINTS
-- =========================================================
--
-- 04.1 Monthly Aggregation          : PASSED
-- 04.2 Consolidated KPI Scorecard   : PASSED
-- 04.3A Fill Rate MoM               : PASSED
-- 04.3B Remaining KPI MoM           : PASSED
-- 04.4 Historical Database QA       : PASSED
--
-- TOTAL REPORTING MONTHS:
-- 12
--
-- TOTAL CORE KPI MEASURES:
-- 10
--
-- ADDITIONAL MOM MOVEMENT MEASURES:
-- 13 (excluding Fill Rate)
--
-- =========================================================
-- F. IMPORTANT BUSINESS LIMITATIONS
-- =========================================================
--
-- 1. All data represents a synthetic scenario.
--
-- 2. Passing database-level QA does not prove
--    the operational accuracy of source events.
--
-- 3. This QA does not independently reconcile
--    SQL outputs with the original cleaned CSVs.
--
-- 4. Complete inventory movement equations
--    and source-level supplier relationships
--    require additional reconciliation.
--
-- 5. Historical correlations do not establish
--    supplier or warehouse causation.
--
-- 6. Financial exposure remains an estimated
--    opportunity, not confirmed lost profit.
--
-- 7. All KPI aggregation definitions must be
--    preserved when building Power BI measures.
--
-- =========================================================
-- G. NEXT VALIDATION
-- =========================================================
--
-- SQL SCRIPT 09:
-- Independent SQL-Python Reconciliation
--
-- OBJECTIVES:
-- Compare source-level values and aggregate KPIs
-- across all 12 months.
--
-- Confirm inventory equations, supplier references,
-- derived financial fields and reporting consistency.
--
-- =========================================================
-- SCRIPT 04 VALIDATION STATUS:
-- DATABASE-LEVEL QA PASSED
--
-- Independent source-level QA remains pending.
-- =========================================================