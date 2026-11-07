-- =========================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 05: WAREHOUSE PERFORMANCE & RISK RANKING
-- =========================================================
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- SOURCE DATABASE:
-- supply_chain_ai_db
--
-- SOURCE TABLE:
-- inventory
--
-- REPORTING PERIOD:
-- October 2026 (initial baseline)
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- BUSINESS OBJECTIVE:
-- Compare warehouse-level service performance,
-- inventory availability and financial exposure.
--
-- SCRIPT ROADMAP:
-- 05.1 October Warehouse KPI Comparison
-- 05.2 Warehouse Risk Ranking & Contribution
-- 05.3 Historical Warehouse Performance
-- 05.4 Warehouse Reconciliation & Findings
--
-- IMPORTANT:
-- Use the same KPI definitions as Script 03.
-- Do not assume the worst warehouse before
-- investigating the actual SQL results.
-- =========================================================


-- =========================================================
-- SECTION 05.1: OCTOBER WAREHOUSE KPI COMPARISON
-- =========================================================
--
-- BUSINESS QUESTION:
-- How did North, South and West perform during
-- October 2026?
--
-- OUTPUT:
-- Vertical metric | value report
--
-- EXPECTED:
-- 3 warehouses with 120 SKU records each.
--
-- KEY METRICS:
-- 1. Inventory Locations
-- 2. Distinct SKUs
-- 3. Customer Demand
-- 4. Fulfilled Demand
-- 5. Unfulfilled Demand
-- 6. Fill Rate
-- 7. Stockout Locations
-- 8. Stockout Rate
-- 9. Zero-Stock Locations
-- 10. Positive-Stock At-Risk Locations
-- 11. At-Risk Rate
-- 12. Closing Inventory Value
-- 13. Potential Gross-Margin Exposure
-- =========================================================

WITH warehouse_base AS (

    SELECT

        warehouse,

        COUNT(*)
            AS total_locations,

        COUNT(DISTINCT sku_id)
            AS distinct_skus,

        -- Demand and fulfillment
        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        SUM(demand_units - fulfilled_units)
            AS total_unfulfilled_units,

        -- Stockout occurrence
        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1
                ELSE 0
            END
        ) AS stockout_locations,

        -- Zero closing stock
        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1
                ELSE 0
            END
        ) AS zero_stock_locations,

        -- Positive-stock reorder risk
        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1
                ELSE 0
            END
        ) AS at_risk_locations,

        -- Financial inventory valuation
        SUM(closing_stock_units * unit_cost)
            AS closing_inventory_value_inr,

        -- Positive gross-margin opportunity
        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

    GROUP BY warehouse

),

warehouse_kpis AS (

    SELECT

        warehouse,

        total_locations,

        distinct_skus,

        total_demand_units,

        total_fulfilled_units,

        total_unfulfilled_units,

        ROUND(
            total_fulfilled_units * 100.0 /
            NULLIF(total_demand_units, 0),
            2
        ) AS fill_rate_pct,

        stockout_locations,

        ROUND(
            stockout_locations * 100.0 /
            NULLIF(total_locations, 0),
            2
        ) AS stockout_rate_pct,

        zero_stock_locations,

        at_risk_locations,

        ROUND(
            at_risk_locations * 100.0 /
            NULLIF(total_locations, 0),
            2
        ) AS at_risk_rate_pct,

        ROUND(
            closing_inventory_value_inr,
            2
        ) AS closing_inventory_value_inr,

        ROUND(
            potential_margin_exposure_inr,
            2
        ) AS potential_margin_exposure_inr

    FROM warehouse_base

),

warehouse_metrics AS (

    SELECT warehouse, 1 AS sort_order,
           'Inventory Locations' AS metric,
           total_locations AS value
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 2,
           'Distinct SKUs',
           distinct_skus
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 3,
           'Total Demand Units',
           total_demand_units
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 4,
           'Total Fulfilled Units',
           total_fulfilled_units
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 5,
           'Total Unfulfilled Units',
           total_unfulfilled_units
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 6,
           'Fill Rate (%)',
           fill_rate_pct
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 7,
           'Stockout Locations',
           stockout_locations
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 8,
           'Stockout Rate (%)',
           stockout_rate_pct
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 9,
           'Zero-Stock Locations',
           zero_stock_locations
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 10,
           'Positive-Stock At-Risk Locations',
           at_risk_locations
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 11,
           'At-Risk Rate (%)',
           at_risk_rate_pct
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 12,
           'Closing Inventory Value (INR)',
           closing_inventory_value_inr
    FROM warehouse_kpis

    UNION ALL

    SELECT warehouse, 13,
           'Potential Margin Exposure (INR)',
           potential_margin_exposure_inr
    FROM warehouse_kpis

)

SELECT

    CONCAT(
        warehouse,
        ' | ',
        metric
    ) AS metric,

    value

FROM warehouse_metrics

ORDER BY warehouse, sort_order;
-- =========================================================
-- SECTION 05.1: VERIFIED WAREHOUSE KPI RESULTS
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
-- REPORTING PERIOD: October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT:
-- 3 Warehouses x 13 Metrics = 39 Result Rows
--
-- EXECUTION STATUS:
-- PASSED
--
-- =========================================================
-- A. NORTH WAREHOUSE
-- =========================================================
--
-- Inventory Locations            : 120
-- Distinct SKUs                  : 120
-- Total Demand Units             : 18331
-- Total Fulfilled Units          : 17290
-- Total Unfulfilled Units        : 1041
-- Fill Rate                      : 94.32%
-- Stockout Locations             : 22
-- Stockout Rate                  : 18.33%
-- Zero-Stock Locations           : 22
-- Positive-Stock At-Risk         : 48
-- At-Risk Rate                   : 40.00%
-- Closing Inventory Value        : 22462395.50 INR
-- Potential Margin Exposure      : 919223.91 INR
--
-- =========================================================
-- B. SOUTH WAREHOUSE
-- =========================================================
--
-- Inventory Locations            : 120
-- Distinct SKUs                  : 120
-- Total Demand Units             : 16723
-- Total Fulfilled Units          : 15392
-- Total Unfulfilled Units        : 1331
-- Fill Rate                      : 92.04%
-- Stockout Locations             : 30
-- Stockout Rate                  : 25.00%
-- Zero-Stock Locations           : 30
-- Positive-Stock At-Risk         : 45
-- At-Risk Rate                   : 37.50%
-- Closing Inventory Value        : 18035193.27 INR
-- Potential Margin Exposure      : 1022586.75 INR
--
-- =========================================================
-- C. WEST WAREHOUSE
-- =========================================================
--
-- Inventory Locations            : 120
-- Distinct SKUs                  : 120
-- Total Demand Units             : 16549
-- Total Fulfilled Units          : 15240
-- Total Unfulfilled Units        : 1309
-- Fill Rate                      : 92.09%
-- Stockout Locations             : 27
-- Stockout Rate                  : 22.50%
-- Zero-Stock Locations           : 27
-- Positive-Stock At-Risk         : 48
-- At-Risk Rate                   : 40.00%
-- Closing Inventory Value        : 17529499.96 INR
-- Potential Margin Exposure      : 1129395.17 INR
--
-- =========================================================
-- D. COMPANY-WIDE RECONCILIATION
-- =========================================================
--
-- Total Inventory Locations:
-- 120 + 120 + 120 = 360
--
-- Total Demand:
-- 18331 + 16723 + 16549 = 51603
--
-- Total Fulfilled:
-- 17290 + 15392 + 15240 = 47922
--
-- Total Unfulfilled:
-- 1041 + 1331 + 1309 = 3681
--
-- Total Stockout Locations:
-- 22 + 30 + 27 = 79
--
-- Total Zero-Stock Locations:
-- 22 + 30 + 27 = 79
--
-- Total Positive-Stock At-Risk Locations:
-- 48 + 45 + 48 = 141
--
-- Closing Inventory Value:
-- 22462395.50 + 18035193.27 + 17529499.96
-- = 58027088.73 INR
--
-- Potential Gross-Margin Exposure:
-- 919223.91 + 1022586.75 + 1129395.17
-- = 3071205.83 INR
--
-- RECONCILIATION RESULT:
-- All additive warehouse metrics match the
-- verified October company-level KPI totals.
--
-- =========================================================
-- E. WAREHOUSE RANKINGS
-- =========================================================
--
-- LOWEST FILL RATE:
-- 1. South : 92.04%
-- 2. West  : 92.09%
-- 3. North : 94.32%
--
-- HIGHEST STOCKOUT RATE:
-- 1. South : 25.00%
-- 2. West  : 22.50%
-- 3. North : 18.33%
--
-- MOST UNFULFILLED UNITS:
-- 1. South : 1331
-- 2. West  : 1309
-- 3. North : 1041
--
-- HIGHEST POTENTIAL MARGIN EXPOSURE:
-- 1. West  : 1129395.17 INR
-- 2. South : 1022586.75 INR
-- 3. North : 919223.91 INR
--
-- HIGHEST POSITIVE-STOCK AT-RISK COUNT:
-- North : 48
-- West  : 48
-- South : 45
--
-- =========================================================
-- F. FINANCIAL AND OPERATIONAL CONTRIBUTION
-- =========================================================
--
-- SHARE OF TOTAL UNFULFILLED UNITS:
-- North : 28.28%
-- South : 36.16%
-- West  : 35.56%
--
-- SHARE OF POTENTIAL MARGIN EXPOSURE:
-- North : 29.93%
-- South : 33.30%
-- West  : 36.77%
--
-- SOUTH:
-- Highest unfulfilled demand and stockout rate.
-- Primary candidate for fulfillment investigation.
--
-- WEST:
-- Highest potential gross-margin exposure.
-- Primary candidate for financial risk investigation.
--
-- NORTH:
-- Highest Fill Rate and lowest stockout rate.
-- However, 48 locations remain below reorder
-- thresholds while holding positive stock.
--
-- =========================================================
-- G. BUSINESS LIMITATIONS
-- =========================================================
--
-- 1. Results represent a synthetic scenario.
-- 2. Rankings indicate investigation priorities,
--    not established root causes.
-- 3. Margin exposure is not confirmed lost profit.
-- 4. Stockout and zero-stock counts may represent
--    different SKU-warehouse records.
-- 5. One reporting month does not establish
--    persistent warehouse underperformance.
-- 6. Supplier causes require separate investigation.
-- 7. Inventory availability and financial exposure
--    must be considered together.
--
-- =========================================================
-- H. NEXT ANALYSIS
-- =========================================================
--
-- SECTION 05.2:
-- Warehouse Risk Ranking & Contribution
--
-- Calculate warehouse shares of:
-- - Demand
-- - Unfulfilled Units
-- - Stockout Locations
-- - Potential Gross-Margin Exposure
--
-- Rank operational and financial risks using
-- transparent SQL window functions.
--
-- VALIDATION STATUS:
-- October warehouse KPI outputs reconciled.
-- Historical warehouse analysis remains pending.
-- =========================================================
-- =========================================================
-- SECTION 05.2: WAREHOUSE RISK RANKING & CONTRIBUTION
-- =========================================================
--
-- BUSINESS QUESTION:
-- Which warehouses contribute disproportionately
-- to supply chain risks and financial exposure?
--
-- REPORTING PERIOD:
-- October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT:
-- 3 Warehouses x 12 Metrics = 36 Rows
-- Vertical Metric | Value Format
--
-- ANALYTICAL METHOD:
-- 1. Aggregate operational and financial totals.
-- 2. Calculate warehouse-level KPI rates.
-- 3. Calculate each warehouse's portfolio shares.
-- 4. Rank individual risk dimensions.
-- 5. Preserve ties using DENSE_RANK().
--
-- IMPORTANT:
-- Rank 1 identifies the greatest concern
-- within that specific ranking dimension.
--
-- No arbitrary composite risk score is used.
-- =========================================================

WITH warehouse_base AS (

    SELECT

        warehouse,

        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        SUM(demand_units - fulfilled_units)
            AS total_unfulfilled_units,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        COUNT(*) AS total_locations,

        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

    GROUP BY warehouse

),

warehouse_kpis AS (

    SELECT

        warehouse,

        total_demand_units,

        total_unfulfilled_units,

        stockout_locations,

        at_risk_locations,

        potential_margin_exposure_inr,

        -- Warehouse Fill Rate
        total_fulfilled_units * 100.0 /
        NULLIF(total_demand_units, 0)
            AS fill_rate_pct,

        -- Warehouse Stockout Rate
        stockout_locations * 100.0 /
        NULLIF(total_locations, 0)
            AS stockout_rate_pct,

        -- Unfulfilled Demand Rate
        total_unfulfilled_units * 100.0 /
        NULLIF(total_demand_units, 0)
            AS unfulfilled_demand_rate_pct,

        -- Potential Margin Per Unfulfilled Unit
        potential_margin_exposure_inr /
        NULLIF(total_unfulfilled_units, 0)
            AS margin_per_unfulfilled_unit_inr

    FROM warehouse_base

),

warehouse_rankings AS (

    SELECT

        warehouse,

        -- =================================================
        -- CONTRIBUTION PERCENTAGES
        -- =================================================

        -- 1. Demand Contribution
        ROUND(
            total_demand_units * 100.0 /
            NULLIF(
                SUM(total_demand_units) OVER (),
                0
            ),
            2
        ) AS demand_share_pct,

        -- 2. Unfulfilled Demand Contribution
        ROUND(
            total_unfulfilled_units * 100.0 /
            NULLIF(
                SUM(total_unfulfilled_units) OVER (),
                0
            ),
            2
        ) AS unfulfilled_share_pct,

        -- 3. Stockout Location Contribution
        ROUND(
            stockout_locations * 100.0 /
            NULLIF(
                SUM(stockout_locations) OVER (),
                0
            ),
            2
        ) AS stockout_share_pct,

        -- 4. At-Risk Location Contribution
        ROUND(
            at_risk_locations * 100.0 /
            NULLIF(
                SUM(at_risk_locations) OVER (),
                0
            ),
            2
        ) AS at_risk_share_pct,

        -- 5. Financial Exposure Contribution
        ROUND(
            potential_margin_exposure_inr * 100.0 /
            NULLIF(
                SUM(potential_margin_exposure_inr)
                OVER (),
                0
            ),
            2
        ) AS margin_exposure_share_pct,

        -- =================================================
        -- SUPPORTING MEASURES
        -- =================================================

        ROUND(
            unfulfilled_demand_rate_pct,
            2
        ) AS unfulfilled_demand_rate_pct,

        ROUND(
            margin_per_unfulfilled_unit_inr,
            2
        ) AS margin_per_unfulfilled_unit_inr,

        -- =================================================
        -- INDEPENDENT RISK RANKINGS
        -- =================================================

        -- 1. Lowest Fill Rate = Rank 1
        DENSE_RANK() OVER (
            ORDER BY fill_rate_pct ASC
        ) AS fill_rate_risk_rank,

        -- 2. Highest Stockout Rate = Rank 1
        DENSE_RANK() OVER (
            ORDER BY stockout_rate_pct DESC
        ) AS stockout_risk_rank,

        -- 3. Most Unfulfilled Units = Rank 1
        DENSE_RANK() OVER (
            ORDER BY total_unfulfilled_units DESC
        ) AS unfulfilled_demand_rank,

        -- 4. Highest Financial Exposure = Rank 1
        DENSE_RANK() OVER (
            ORDER BY potential_margin_exposure_inr DESC
        ) AS financial_exposure_rank,

        -- 5. Most At-Risk Locations = Rank 1
        DENSE_RANK() OVER (
            ORDER BY at_risk_locations DESC
        ) AS at_risk_inventory_rank

    FROM warehouse_kpis

),

warehouse_metrics AS (

    SELECT warehouse, 1 AS sort_order,
           'Demand Contribution (%)' AS metric,
           demand_share_pct AS value
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 2,
           'Unfulfilled Demand Contribution (%)',
           unfulfilled_share_pct
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 3,
           'Stockout Location Contribution (%)',
           stockout_share_pct
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 4,
           'At-Risk Location Contribution (%)',
           at_risk_share_pct
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 5,
           'Potential Margin Exposure Contribution (%)',
           margin_exposure_share_pct
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 6,
           'Unfulfilled Demand Rate (%)',
           unfulfilled_demand_rate_pct
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 7,
           'Potential Margin Per Unfulfilled Unit (INR)',
           margin_per_unfulfilled_unit_inr
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 8,
           'Fill Rate Risk Rank',
           fill_rate_risk_rank
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 9,
           'Stockout Risk Rank',
           stockout_risk_rank
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 10,
           'Unfulfilled Demand Rank',
           unfulfilled_demand_rank
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 11,
           'Financial Exposure Rank',
           financial_exposure_rank
    FROM warehouse_rankings

    UNION ALL

    SELECT warehouse, 12,
           'At-Risk Inventory Rank',
           at_risk_inventory_rank
    FROM warehouse_rankings

)

SELECT

    CONCAT(
        warehouse,
        ' | ',
        metric
    ) AS metric,

    value

FROM warehouse_metrics

ORDER BY warehouse, sort_order;
-- =========================================================
-- SECTION 05.2: VERIFIED WAREHOUSE RISK RANKING
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING PERIOD:
-- October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- EXECUTION RESULTS:
-- Warehouses Analyzed       : 3
-- Contribution Measures     : 5
-- Supporting Measures       : 2
-- Independent Risk Rankings : 5
-- Total Result Rows         : 36
--
-- VALIDATION STATUS:
-- PASSED
--
-- =========================================================
-- A. NORTH WAREHOUSE
-- =========================================================
--
-- Demand Contribution               : 35.52%
-- Unfulfilled Demand Contribution   : 28.28%
-- Stockout Location Contribution    : 27.85%
-- At-Risk Location Contribution     : 34.04%
-- Potential Margin Exposure Share   : 29.93%
--
-- Unfulfilled Demand Rate           : 5.68%
-- Margin Per Unfulfilled Unit       : 883.02 INR
--
-- Fill Rate Risk Rank               : 3
-- Stockout Risk Rank                : 3
-- Unfulfilled Demand Rank           : 3
-- Financial Exposure Rank           : 3
-- At-Risk Inventory Rank            : 1
--
-- BUSINESS INTERPRETATION:
-- North has the strongest relative fulfillment
-- performance but shares the highest positive-stock
-- reorder-risk count with West.
--
-- =========================================================
-- B. SOUTH WAREHOUSE
-- =========================================================
--
-- Demand Contribution               : 32.41%
-- Unfulfilled Demand Contribution   : 36.16%
-- Stockout Location Contribution    : 37.97%
-- At-Risk Location Contribution     : 31.91%
-- Potential Margin Exposure Share   : 33.30%
--
-- Unfulfilled Demand Rate           : 7.96%
-- Margin Per Unfulfilled Unit       : 768.28 INR
--
-- Fill Rate Risk Rank               : 1
-- Stockout Risk Rank                : 1
-- Unfulfilled Demand Rank           : 1
-- Financial Exposure Rank           : 2
-- At-Risk Inventory Rank            : 2
--
-- BUSINESS INTERPRETATION:
-- South has the greatest operational service risk
-- across the three selected fulfillment dimensions.
--
-- Its share of unmet demand exceeds its share
-- of customer demand.
--
-- =========================================================
-- C. WEST WAREHOUSE
-- =========================================================
--
-- Demand Contribution               : 32.07%
-- Unfulfilled Demand Contribution   : 35.56%
-- Stockout Location Contribution    : 34.18%
-- At-Risk Location Contribution     : 34.04%
-- Potential Margin Exposure Share   : 36.77%
--
-- Unfulfilled Demand Rate           : 7.91%
-- Margin Per Unfulfilled Unit       : 862.79 INR
--
-- Fill Rate Risk Rank               : 2
-- Stockout Risk Rank                : 2
-- Unfulfilled Demand Rank           : 2
-- Financial Exposure Rank           : 1
-- At-Risk Inventory Rank            : 1
--
-- BUSINESS INTERPRETATION:
-- West contributes the largest share of potential
-- gross-margin exposure.
--
-- It also shares the highest positive-stock
-- reorder-risk count with North.
--
-- =========================================================
-- D. CONTRIBUTION RECONCILIATION
-- =========================================================
--
-- Total Demand Contribution:
-- 35.52 + 32.41 + 32.07 = 100.00%
--
-- Total Unfulfilled Demand Contribution:
-- 28.28 + 36.16 + 35.56 = 100.00%
--
-- Total Stockout Location Contribution:
-- 27.85 + 37.97 + 34.18 = 100.00%
--
-- Total At-Risk Location Contribution:
-- 34.04 + 31.91 + 34.04 = 99.99%
--
-- Total Financial Exposure Contribution:
-- 29.93 + 33.30 + 36.77 = 100.00%
--
-- NOTE:
-- The 99.99% at-risk total is caused by
-- rounding individual contribution values.
--
-- Unrounded contributions sum to 100%.
--
-- =========================================================
-- E. DISPROPORTIONATE CONTRIBUTIONS
-- =========================================================
--
-- SOUTH:
-- Unfulfilled Demand Share - Demand Share
-- = 36.16 - 32.41
-- = +3.75 percentage points
--
-- WEST:
-- Potential Margin Exposure Share - Demand Share
-- = 36.77 - 32.07
-- = +4.70 percentage points
--
-- NORTH:
-- Unfulfilled Demand Share - Demand Share
-- = 28.28 - 35.52
-- = -7.24 percentage points
--
-- These are descriptive comparisons, not
-- causal impact estimates.
--
-- =========================================================
-- F. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- PRIORITY 1: OPERATIONAL SERVICE RISK
-- Warehouse: South
--
-- Evidence:
-- Lowest Fill Rate.
-- Highest Stockout Rate.
-- Highest total unfulfilled demand.
-- Highest share of unfulfilled demand.
--
-- Recommended Investigation:
-- Identify SKUs responsible for unmet demand.
-- Examine inventory availability and replenishment.
--
-- PRIORITY 2: POTENTIAL FINANCIAL EXPOSURE
-- Warehouse: West
--
-- Evidence:
-- Highest estimated margin exposure.
-- Largest share of portfolio financial exposure.
--
-- Recommended Investigation:
-- Identify high-margin shortage SKUs and assess
-- recovery opportunities.
--
-- PRIORITY 3: POSITIVE-STOCK REORDER RISK
-- Warehouses: North and West
--
-- Evidence:
-- 48 at-risk SKU locations in each warehouse.
--
-- Recommended Investigation:
-- Compare current coverage with expected demand,
-- reorder thresholds and supplier lead times.
--
-- =========================================================
-- G. SQL METHOD
-- =========================================================
--
-- SUM(metric) OVER():
-- Calculates portfolio totals while preserving
-- individual warehouse rows.
--
-- DENSE_RANK():
-- Assigns rankings and preserves equal ranks.
--
-- The at-risk inventory ranking correctly assigns
-- Rank 1 to both North and West.
--
-- Separate ranking dimensions are retained.
-- No arbitrary composite score was introduced.
--
-- =========================================================
-- H. LIMITATIONS
-- =========================================================
--
-- 1. Data represents a synthetic business scenario.
--
-- 2. Results describe October 2026 only.
--
-- 3. High risk rankings do not establish causes.
--
-- 4. Potential margin exposure is not confirmed
--    lost sales or realized profit loss.
--
-- 5. At-risk locations are defined as positive
--    closing stock below reorder point.
--
-- 6. Zero-stock locations are excluded from the
--    positive-stock at-risk count.
--
-- 7. Historical comparisons are necessary before
--    claiming persistent underperformance.
--
-- =========================================================
-- NEXT ANALYSIS:
-- SECTION 05.3: HISTORICAL WAREHOUSE PERFORMANCE
-- =========================================================
--
-- Examine North, South and West across all 12 months.
--
-- Compare monthly Fill Rates, stockout rates,
-- unfulfilled demand and potential financial exposure.
--
-- Investigate September-to-October changes.
--
-- VALIDATION STATUS:
-- Section 05.2 calculations and rankings verified.
-- =========================================================
-- =========================================================
-- SECTION 05.3: HISTORICAL WAREHOUSE PERFORMANCE
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
-- BUSINESS QUESTIONS:
-- 1. How did each warehouse perform over 12 months?
-- 2. Are October's problems persistent or recent?
-- 3. How did warehouse KPIs change month to month?
-- 4. Which warehouse deserves deeper investigation?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT GRAIN:
-- One Warehouse x One Reporting Month
--
-- EXPECTED OUTPUT:
-- 3 Warehouses x 12 Months = 36 Rows
--
-- METHODOLOGY:
-- 1. Aggregate metrics at warehouse-month level.
-- 2. Calculate warehouse-month KPI rates.
-- 3. Use LAG() separately within each warehouse.
-- 4. Calculate month-over-month changes.
-- 5. Preserve full precision before final rounding.
--
-- IMPORTANT:
-- The first reporting month of each warehouse
-- has no previous month and returns NULL for MoM.
--
-- Historical patterns do not establish causality.
-- =========================================================

WITH warehouse_monthly_base AS (

    SELECT

        reporting_month,

        warehouse,

        COUNT(*) AS inventory_locations,

        -- Customer demand
        SUM(demand_units)
            AS demand_units,

        -- Fulfilled demand
        SUM(fulfilled_units)
            AS fulfilled_units,

        -- Unfulfilled demand
        SUM(demand_units - fulfilled_units)
            AS unfulfilled_units,

        -- Stockout occurrence
        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1
                ELSE 0
            END
        ) AS stockout_locations,

        -- Positive-stock reorder risk
        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1
                ELSE 0
            END
        ) AS at_risk_locations,

        -- Potential gross-margin exposure
        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month BETWEEN
          '2025-11-01' AND '2026-10-01'

    GROUP BY reporting_month, warehouse

),

warehouse_monthly_kpis AS (

    SELECT

        reporting_month,

        warehouse,

        inventory_locations,

        demand_units,

        unfulfilled_units,

        stockout_locations,

        at_risk_locations,

        margin_exposure_inr,

        -- Fill Rate
        fulfilled_units * 100.0 /
        NULLIF(demand_units, 0)
            AS fill_rate_pct,

        -- Stockout Rate
        stockout_locations * 100.0 /
        NULLIF(inventory_locations, 0)
            AS stockout_rate_pct

    FROM warehouse_monthly_base

),

warehouse_previous_month AS (

    SELECT

        warehouse_monthly_kpis.*,

        -- Previous observation for the same warehouse
        LAG(reporting_month)
        OVER (
            PARTITION BY warehouse
            ORDER BY reporting_month
        ) AS previous_reporting_month,

        -- Previous month's Fill Rate
        LAG(fill_rate_pct)
        OVER (
            PARTITION BY warehouse
            ORDER BY reporting_month
        ) AS previous_fill_rate_pct,

        -- Previous month's Stockout Rate
        LAG(stockout_rate_pct)
        OVER (
            PARTITION BY warehouse
            ORDER BY reporting_month
        ) AS previous_stockout_rate_pct,

        -- Previous month's Unfulfilled Demand
        LAG(unfulfilled_units)
        OVER (
            PARTITION BY warehouse
            ORDER BY reporting_month
        ) AS previous_unfulfilled_units,

        -- Previous month's Margin Exposure
        LAG(margin_exposure_inr)
        OVER (
            PARTITION BY warehouse
            ORDER BY reporting_month
        ) AS previous_margin_exposure_inr

    FROM warehouse_monthly_kpis

)

SELECT

    DATE_FORMAT(
        reporting_month, '%Y-%m'
    ) AS reporting_month,

    warehouse,

    inventory_locations,

    demand_units,

    -- Current monthly Fill Rate
    ROUND(
        fill_rate_pct,
        2
    ) AS fill_rate_pct,

    -- Fill Rate MoM change in percentage points
    ROUND(
        fill_rate_pct - previous_fill_rate_pct,
        2
    ) AS fill_rate_mom_change_pp,

    -- Current monthly Stockout Rate
    ROUND(
        stockout_rate_pct,
        2
    ) AS stockout_rate_pct,

    -- Stockout Rate MoM change
    ROUND(
        stockout_rate_pct - previous_stockout_rate_pct,
        2
    ) AS stockout_mom_change_pp,

    -- Positive-stock at-risk locations
    at_risk_locations,

    -- Current monthly unfulfilled demand
    unfulfilled_units,

    -- Unfulfilled demand MoM unit change
    unfulfilled_units - previous_unfulfilled_units
        AS unfulfilled_mom_change_units,

    -- Current monthly margin exposure
    ROUND(
        margin_exposure_inr,
        2
    ) AS margin_exposure_inr,

    -- Margin exposure MoM percentage change
    ROUND(
        (
            margin_exposure_inr
            - previous_margin_exposure_inr
        ) * 100.0 /
        NULLIF(previous_margin_exposure_inr, 0),
        2
    ) AS margin_exposure_mom_change_pct

FROM warehouse_previous_month

ORDER BY reporting_month, warehouse;
-- =========================================================
-- SECTION 05.3: VERIFIED HISTORICAL WAREHOUSE PERFORMANCE
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
-- SOURCE GRAIN:
-- One SKU x Warehouse x Month
--
-- OUTPUT GRAIN:
-- One Warehouse x Reporting Month
--
-- EXECUTION RESULTS:
-- Warehouses Analyzed       : 3
-- Months Analyzed           : 12
-- Warehouse-Month Rows      : 36
-- Inventory Locations/Row  : 120
-- Output Columns            : 13
--
-- VALIDATION STATUS: PASSED
--
-- =========================================================
-- A. HISTORICAL RECONCILIATION
-- =========================================================
--
-- All 12 reporting months reconciled with
-- the company-level monthly results in Script 04.
--
-- Monthly checks included:
-- - Demand Units
-- - Fulfilled Units
-- - Unfulfilled Units
-- - Stockout Location Counts
-- - Positive-Stock At-Risk Counts
-- - Potential Gross-Margin Exposure
--
-- October warehouse KPIs matched Section 05.1.
--
-- All applicable MoM changes matched their
-- recalculated values using unrounded inputs.
--
-- November 2025 MoM comparisons correctly
-- returned NULL for all three warehouses.
--
-- =========================================================
-- B. NORTH: 12-MONTH PERFORMANCE
-- =========================================================
--
-- Total Demand Units:
-- 208252
--
-- Total Fulfilled Units:
-- 196222
--
-- Total Unfulfilled Units:
-- 12030
--
-- Weighted Fill Rate:
-- 196222 / 208252 * 100
-- = 94.22%
--
-- Stockout Location-Month Occurrences:
-- 254
--
-- Positive-Stock At-Risk Location-Month Occurrences:
-- 523
--
-- Cumulative Potential Margin Exposure:
-- 9622353.90 INR
--
-- Months With Lowest Fill Rate:
-- 3 of 12
--
-- Months With Highest Margin Exposure:
-- 2 of 12
--
-- INTERPRETATION:
-- North had the strongest weighted Fill Rate
-- across the complete reporting period.
--
-- Replenishment risks remain despite relatively
-- stronger historical fulfillment performance.
--
-- =========================================================
-- C. SOUTH: 12-MONTH PERFORMANCE
-- =========================================================
--
-- Total Demand Units:
-- 186775
--
-- Total Fulfilled Units:
-- 175006
--
-- Total Unfulfilled Units:
-- 11769
--
-- Weighted Fill Rate:
-- 175006 / 186775 * 100
-- = 93.70%
--
-- Stockout Location-Month Occurrences:
-- 288
--
-- Positive-Stock At-Risk Location-Month Occurrences:
-- 536
--
-- Cumulative Potential Margin Exposure:
-- 10422617.21 INR
--
-- Months With Lowest Fill Rate:
-- 4 of 12
--
-- Months With Highest Margin Exposure:
-- 2 of 12
--
-- INTERPRETATION:
-- South recorded the highest stockout
-- location-month occurrence count.
--
-- It also had the weakest October Fill Rate
-- and the largest October unfulfilled demand.
--
-- =========================================================
-- D. WEST: 12-MONTH PERFORMANCE
-- =========================================================
--
-- Total Demand Units:
-- 195505
--
-- Total Fulfilled Units:
-- 182880
--
-- Total Unfulfilled Units:
-- 12625
--
-- Weighted Fill Rate:
-- 182880 / 195505 * 100
-- = 93.54%
--
-- Stockout Location-Month Occurrences:
-- 273
--
-- Positive-Stock At-Risk Location-Month Occurrences:
-- 555
--
-- Cumulative Potential Margin Exposure:
-- 13013113.49 INR
--
-- Share of 12-Month Potential Margin Exposure:
-- 39.36%
--
-- Share of 12-Month Demand:
-- 33.11%
--
-- Months With Lowest Fill Rate:
-- 5 of 12
--
-- Months With Highest Margin Exposure:
-- 8 of 12
--
-- INTERPRETATION:
-- West had the lowest 12-month demand-weighted
-- Fill Rate of the three warehouses.
--
-- West also had the highest cumulative estimated
-- margin exposure and the most months with
-- the greatest financial exposure.
--
-- =========================================================
-- E. PORTFOLIO RECONCILIATION
-- =========================================================
--
-- Total Demand:
-- 208252 + 186775 + 195505
-- = 590532 units
--
-- Total Fulfilled:
-- 196222 + 175006 + 182880
-- = 554108 units
--
-- Total Unfulfilled:
-- 12030 + 11769 + 12625
-- = 36424 units
--
-- Portfolio 12-Month Weighted Fill Rate:
-- 554108 / 590532 * 100
-- = 93.83%
--
-- Total Stockout Location-Month Occurrences:
-- 254 + 288 + 273
-- = 815
--
-- Total At-Risk Location-Month Occurrences:
-- 523 + 536 + 555
-- = 1614
--
-- Cumulative Potential Margin Exposure:
-- 9622353.90 + 10422617.21 + 13013113.49
-- = 33058084.60 INR
--
-- IMPORTANT:
-- Cumulative margin exposure is an estimate
-- across monthly unmet-demand observations.
-- It is not confirmed realized financial loss.
--
-- =========================================================
-- F. LOWEST MONTHLY FILL RATE FREQUENCY
-- =========================================================
--
-- North:
-- 3 months
-- February, April and July 2026
--
-- South:
-- 4 months
-- December 2025; January, May and October 2026
--
-- West:
-- 5 months
-- November 2025; March, June,
-- August and September 2026
--
-- RESULT:
-- West had the lowest Fill Rate most frequently.
--
-- =========================================================
-- G. HIGHEST MONTHLY MARGIN EXPOSURE FREQUENCY
-- =========================================================
--
-- North:
-- 2 months
--
-- South:
-- 2 months
--
-- West:
-- 8 months
--
-- RESULT:
-- West had the greatest potential margin
-- exposure in two-thirds of the reporting months.
--
-- =========================================================
-- H. SEPTEMBER TO OCTOBER MOVEMENT
-- =========================================================
--
-- NORTH:
-- Fill Rate Change       : +1.82 pp
-- Stockout Rate Change   : +1.67 pp
-- Unfulfilled Units      : -409
-- Margin Exposure Change : -24.26%
--
-- SOUTH:
-- Fill Rate Change       : -0.27 pp
-- Stockout Rate Change   : +2.50 pp
-- Unfulfilled Units      : +63
-- Margin Exposure Change : -20.55%
--
-- WEST:
-- Fill Rate Change       : +0.65 pp
-- Stockout Rate Change   : +5.00 pp
-- Unfulfilled Units      : -165
-- Margin Exposure Change : -31.70%
--
-- INTERPRETATION:
-- South was the only warehouse with an increase
-- in unfulfilled units during October.
--
-- West had the largest increase in stockout
-- occurrence rate, despite lower unmet demand.
--
-- Financial exposure decreased at all three
-- warehouses in October.
--
-- =========================================================
-- I. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- SHORT-TERM OPERATIONAL INVESTIGATION:
-- South
--
-- Reason:
-- Lowest October Fill Rate, most October
-- stockout locations and highest unmet demand.
--
-- HISTORICAL FINANCIAL INVESTIGATION:
-- West
--
-- Reason:
-- Highest cumulative estimated margin exposure.
-- Highest monthly financial exposure in 8 of
-- the 12 reporting months.
--
-- PREVENTIVE INVENTORY RISK INVESTIGATION:
-- North and West for October;
-- West for accumulated at-risk location-month
-- occurrences across the reporting period.
--
-- These are investigation priorities,
-- not confirmed root causes.
--
-- =========================================================
-- J. SQL TECHNIQUES
-- =========================================================
--
-- GROUP BY reporting_month, warehouse:
-- Produces warehouse-month aggregates.
--
-- LAG() OVER (
--     PARTITION BY warehouse
--     ORDER BY reporting_month
-- ):
-- Retrieves the prior monthly observation
-- within the same warehouse.
--
-- ROUND():
-- Applied after full-precision calculations.
--
-- NULLIF():
-- Prevents invalid division by zero.
--
-- =========================================================
-- K. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business data.
--
-- 2. Monthly trends do not establish causes.
--
-- 3. Weighted Fill Rates use total fulfilled
--    units divided by total demanded units.
--
-- 4. Stockout and at-risk counts across months
--    represent location-month occurrences, not
--    necessarily unique affected locations.
--
-- 5. Cumulative financial exposure is estimated,
--    not confirmed realized lost profit.
--
-- 6. Supplier and SKU-level investigation is
--    still necessary before corrective actions.
--
-- 7. Independent SQL-Python source reconciliation
--    remains pending.
--
-- =========================================================
-- NEXT:
-- SECTION 05.4: FINAL WAREHOUSE QA & RECONCILIATION
-- =========================================================
-- =========================================================
-- SECTION 05.4: FINAL WAREHOUSE RECONCILIATION & QA
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- PURPOSE:
-- 1. Validate all 36 warehouse-month combinations.
-- 2. Verify each warehouse-month contains 120 SKUs.
-- 3. Reconcile warehouse totals to monthly portfolio.
-- 4. Verify October warehouse benchmarks.
-- 5. Verify 12-month warehouse benchmarks.
--
-- OUTPUT:
-- Vertical Metric | Value QA Report
--
-- IMPORTANT:
-- The monthly portfolio comparison uses the same
-- database source but a separate aggregation path.
--
-- Independent SQL-Python verification remains
-- scheduled for Script 09.
-- =========================================================

WITH warehouse_month AS (

    SELECT

        reporting_month,
        warehouse,

        COUNT(*) AS location_records,

        COUNT(DISTINCT sku_id) AS distinct_skus,

        SUM(demand_units) AS demand_units,

        SUM(fulfilled_units) AS fulfilled_units,

        SUM(demand_units - fulfilled_units)
            AS unfulfilled_units,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        SUM(closing_stock_units * unit_cost)
            AS inventory_value_inr,

        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    GROUP BY reporting_month, warehouse

),

-- Monthly portfolio calculated directly from source.
portfolio_month AS (

    SELECT

        reporting_month,

        COUNT(*) AS source_records,

        SUM(demand_units) AS demand_units,

        SUM(fulfilled_units) AS fulfilled_units,

        SUM(demand_units - fulfilled_units)
            AS unfulfilled_units,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        SUM(closing_stock_units * unit_cost)
            AS inventory_value_inr,

        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    GROUP BY reporting_month

),

-- Monthly portfolio reconstructed from warehouses.
warehouse_rollup AS (

    SELECT

        reporting_month,

        COUNT(*) AS warehouse_groups,

        SUM(location_records) AS location_records,

        SUM(
            CASE
                WHEN location_records <> 120
                THEN 1 ELSE 0
            END
        ) AS invalid_location_groups,

        SUM(
            CASE
                WHEN distinct_skus <> 120
                THEN 1 ELSE 0
            END
        ) AS invalid_sku_groups,

        SUM(
            CASE
                WHEN warehouse IS NULL
                  OR warehouse NOT IN (
                      'North', 'South', 'West'
                  )
                THEN location_records
                ELSE 0
            END
        ) AS invalid_warehouse_key_records,

        SUM(demand_units) AS demand_units,

        SUM(fulfilled_units) AS fulfilled_units,

        SUM(unfulfilled_units) AS unfulfilled_units,

        SUM(stockout_locations) AS stockout_locations,

        SUM(at_risk_locations) AS at_risk_locations,

        SUM(inventory_value_inr) AS inventory_value_inr,

        SUM(margin_exposure_inr) AS margin_exposure_inr

    FROM warehouse_month

    GROUP BY reporting_month

),

-- Compare the two monthly aggregation paths.
monthly_comparison AS (

    SELECT

        p.reporting_month,

        p.source_records,

        w.warehouse_groups,

        w.invalid_location_groups,

        w.invalid_sku_groups,

        w.invalid_warehouse_key_records,

        p.source_records - w.location_records
            AS record_difference,

        p.demand_units - w.demand_units
            AS demand_difference,

        p.fulfilled_units - w.fulfilled_units
            AS fulfilled_difference,

        p.unfulfilled_units - w.unfulfilled_units
            AS unfulfilled_difference,

        p.stockout_locations - w.stockout_locations
            AS stockout_difference,

        p.at_risk_locations - w.at_risk_locations
            AS at_risk_difference,

        p.inventory_value_inr - w.inventory_value_inr
            AS inventory_value_difference,

        p.margin_exposure_inr - w.margin_exposure_inr
            AS margin_exposure_difference

    FROM portfolio_month AS p

    LEFT JOIN warehouse_rollup AS w

        ON p.reporting_month = w.reporting_month

),

-- Check chronological continuity and monthly errors.
monthly_validation AS (

    SELECT

        monthly_comparison.*,

        LAG(reporting_month) OVER (
            ORDER BY reporting_month
        ) AS previous_month

    FROM monthly_comparison

),

monthly_flags AS (

    SELECT

        monthly_validation.*,

        CASE

            WHEN reporting_month IS NULL
              OR DAY(reporting_month) <> 1
              OR source_records <> 360
              OR warehouse_groups IS NULL
              OR warehouse_groups <> 3
              OR invalid_location_groups <> 0
              OR invalid_sku_groups <> 0
              OR invalid_warehouse_key_records <> 0
              OR record_difference <> 0
              OR demand_difference <> 0
              OR fulfilled_difference <> 0
              OR unfulfilled_difference <> 0
              OR stockout_difference <> 0
              OR at_risk_difference <> 0
              OR ABS(inventory_value_difference) > 0.01
              OR ABS(margin_exposure_difference) > 0.01
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

    FROM monthly_validation

),

-- Compare October with verified Section 05.1 results.
october_benchmark AS (

    SELECT

        COUNT(*) AS october_warehouse_rows,

        SUM(
            CASE

                WHEN warehouse = 'North'
                 AND location_records = 120
                 AND demand_units = 18331
                 AND fulfilled_units = 17290
                 AND unfulfilled_units = 1041
                 AND stockout_locations = 22
                 AND at_risk_locations = 48
                 AND ABS(
                     inventory_value_inr - 22462395.50
                 ) <= 0.01
                 AND ABS(
                     margin_exposure_inr - 919223.91
                 ) <= 0.01

                THEN 0

                WHEN warehouse = 'South'
                 AND location_records = 120
                 AND demand_units = 16723
                 AND fulfilled_units = 15392
                 AND unfulfilled_units = 1331
                 AND stockout_locations = 30
                 AND at_risk_locations = 45
                 AND ABS(
                     inventory_value_inr - 18035193.27
                 ) <= 0.01
                 AND ABS(
                     margin_exposure_inr - 1022586.75
                 ) <= 0.01

                THEN 0

                WHEN warehouse = 'West'
                 AND location_records = 120
                 AND demand_units = 16549
                 AND fulfilled_units = 15240
                 AND unfulfilled_units = 1309
                 AND stockout_locations = 27
                 AND at_risk_locations = 48
                 AND ABS(
                     inventory_value_inr - 17529499.96
                 ) <= 0.01
                 AND ABS(
                     margin_exposure_inr - 1129395.17
                 ) <= 0.01

                THEN 0

                ELSE 1

            END
        ) AS october_benchmark_failures

    FROM warehouse_month

    WHERE reporting_month = '2026-10-01'

),

-- Calculate twelve-month totals separately by warehouse.
historical_warehouse AS (

    SELECT

        warehouse,

        SUM(demand_units) AS demand_units,

        SUM(fulfilled_units) AS fulfilled_units,

        SUM(unfulfilled_units) AS unfulfilled_units,

        SUM(stockout_locations) AS stockout_locations,

        SUM(at_risk_locations) AS at_risk_locations,

        SUM(margin_exposure_inr) AS margin_exposure_inr

    FROM warehouse_month

    GROUP BY warehouse

),

-- Check against verified Section 05.3 benchmarks.
historical_benchmark AS (

    SELECT

        COUNT(*) AS historical_warehouse_rows,

        SUM(
            CASE

                WHEN warehouse = 'North'
                 AND demand_units = 208252
                 AND fulfilled_units = 196222
                 AND unfulfilled_units = 12030
                 AND stockout_locations = 254
                 AND at_risk_locations = 523
                 AND ABS(
                     margin_exposure_inr - 9622353.90
                 ) <= 0.01

                THEN 0

                WHEN warehouse = 'South'
                 AND demand_units = 186775
                 AND fulfilled_units = 175006
                 AND unfulfilled_units = 11769
                 AND stockout_locations = 288
                 AND at_risk_locations = 536
                 AND ABS(
                     margin_exposure_inr - 10422617.21
                 ) <= 0.01

                THEN 0

                WHEN warehouse = 'West'
                 AND demand_units = 195505
                 AND fulfilled_units = 182880
                 AND unfulfilled_units = 12625
                 AND stockout_locations = 273
                 AND at_risk_locations = 555
                 AND ABS(
                     margin_exposure_inr - 13013113.49
                 ) <= 0.01

                THEN 0

                ELSE 1

            END
        ) AS historical_benchmark_failures

    FROM historical_warehouse

),

qa_summary AS (

    SELECT

        COUNT(*) AS reporting_months,

        MIN(reporting_month) AS first_month,

        MAX(reporting_month) AS last_month,

        SUM(source_records) AS total_source_records,

        SUM(warehouse_groups) AS warehouse_month_rows,

        SUM(
            CASE
                WHEN warehouse_groups <> 3
                THEN 1 ELSE 0
            END
        ) AS months_without_three_warehouses,

        SUM(invalid_location_groups)
            AS invalid_location_groups,

        SUM(invalid_sku_groups)
            AS invalid_sku_groups,

        SUM(invalid_warehouse_key_records)
            AS invalid_warehouse_key_records,

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
        ) AS missing_month_transitions,

        SUM(
            CASE
                WHEN demand_difference <> 0
                THEN 1 ELSE 0
            END
        ) AS demand_mismatch_months,

        SUM(
            CASE
                WHEN fulfilled_difference <> 0
                THEN 1 ELSE 0
            END
        ) AS fulfilled_mismatch_months,

        SUM(
            CASE
                WHEN unfulfilled_difference <> 0
                THEN 1 ELSE 0
            END
        ) AS unfulfilled_mismatch_months,

        SUM(
            CASE
                WHEN stockout_difference <> 0
                THEN 1 ELSE 0
            END
        ) AS stockout_mismatch_months,

        SUM(
            CASE
                WHEN at_risk_difference <> 0
                THEN 1 ELSE 0
            END
        ) AS at_risk_mismatch_months,

        SUM(
            CASE
                WHEN ABS(inventory_value_difference) > 0.01
                THEN 1 ELSE 0
            END
        ) AS inventory_value_mismatch_months,

        SUM(
            CASE
                WHEN ABS(margin_exposure_difference) > 0.01
                THEN 1 ELSE 0
            END
        ) AS margin_exposure_mismatch_months,

        SUM(month_has_issue) AS months_with_any_failure

    FROM monthly_flags

),

final_summary AS (

    SELECT

        q.*,

        o.october_warehouse_rows,

        o.october_benchmark_failures,

        h.historical_warehouse_rows,

        h.historical_benchmark_failures

    FROM qa_summary AS q

    CROSS JOIN october_benchmark AS o

    CROSS JOIN historical_benchmark AS h

),

qa_results AS (

    SELECT 1 AS sort_order,
           'Reporting Months Found' AS metric,
           CAST(reporting_months AS CHAR) AS value
    FROM final_summary

    UNION ALL

    SELECT 2, 'First Reporting Month',
           DATE_FORMAT(first_month, '%Y-%m')
    FROM final_summary

    UNION ALL

    SELECT 3, 'Last Reporting Month',
           DATE_FORMAT(last_month, '%Y-%m')
    FROM final_summary

    UNION ALL

    SELECT 4, 'Total Source Inventory Records',
           CAST(total_source_records AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 5, 'Warehouse-Month Groups',
           CAST(warehouse_month_rows AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 6, 'Months Without 3 Warehouses',
           CAST(months_without_three_warehouses AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 7, 'Warehouse-Month Groups Without 120 Records',
           CAST(invalid_location_groups AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 8, 'Warehouse-Month Groups Without 120 Unique SKUs',
           CAST(invalid_sku_groups AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 9, 'Invalid Warehouse Key Records',
           CAST(invalid_warehouse_key_records AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 10, 'Missing Monthly Transitions',
           CAST(missing_month_transitions AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 11, 'Monthly Demand Reconciliation Failures',
           CAST(demand_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 12, 'Monthly Fulfilled Reconciliation Failures',
           CAST(fulfilled_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 13, 'Monthly Unfulfilled Reconciliation Failures',
           CAST(unfulfilled_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 14, 'Monthly Stockout Reconciliation Failures',
           CAST(stockout_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 15, 'Monthly At-Risk Reconciliation Failures',
           CAST(at_risk_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 16, 'Monthly Inventory Value Reconciliation Failures',
           CAST(inventory_value_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 17, 'Monthly Margin Exposure Reconciliation Failures',
           CAST(margin_exposure_mismatch_months AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 18, 'October Warehouse Benchmark Failures',
           CAST(october_benchmark_failures AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 19, '12-Month Warehouse Benchmark Failures',
           CAST(historical_benchmark_failures AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 20, 'Months With Any QA Failure',
           CAST(months_with_any_failure AS CHAR)
    FROM final_summary

    UNION ALL

    SELECT 21, 'Overall Warehouse QA Status',

           CASE

               WHEN reporting_months = 12
                AND first_month = '2025-11-01'
                AND last_month = '2026-10-01'
                AND total_source_records = 4320
                AND warehouse_month_rows = 36
                AND months_with_any_failure = 0
                AND october_warehouse_rows = 3
                AND october_benchmark_failures = 0
                AND historical_warehouse_rows = 3
                AND historical_benchmark_failures = 0

               THEN 'PASS'

               ELSE 'FAIL'

           END

    FROM final_summary

)

SELECT metric, value

FROM qa_results

ORDER BY sort_order;
-- =========================================================
-- SECTION 05.4: VERIFIED FINAL WAREHOUSE QA RESULTS
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
-- EXECUTION STATUS:
-- PASS
--
-- =========================================================
-- A. DATA COMPLETENESS
-- =========================================================
--
-- Reporting Months Found                  : 12
-- First Reporting Month                   : 2025-11
-- Last Reporting Month                    : 2026-10
-- Total Source Inventory Records          : 4320
-- Warehouse-Month Groups                  : 36
--
-- Months Without 3 Warehouses             : 0
-- Warehouse-Month Groups Without
-- 120 Records                             : 0
-- Warehouse-Month Groups Without
-- 120 Unique SKUs                         : 0
-- Invalid Warehouse Key Records           : 0
-- Missing Monthly Transitions             : 0
--
-- INTERPRETATION:
-- The expected three-warehouse, twelve-month
-- reporting structure is present.
--
-- Each warehouse-month contains 120 records
-- covering 120 distinct SKUs.
--
-- =========================================================
-- B. MONTHLY PORTFOLIO RECONCILIATION
-- =========================================================
--
-- Monthly Demand Reconciliation
-- Failures                                : 0
--
-- Monthly Fulfilled Reconciliation
-- Failures                                : 0
--
-- Monthly Unfulfilled Reconciliation
-- Failures                                : 0
--
-- Monthly Stockout Reconciliation
-- Failures                                : 0
--
-- Monthly At-Risk Reconciliation
-- Failures                                : 0
--
-- Monthly Inventory Value Reconciliation
-- Failures                                : 0
--
-- Monthly Margin Exposure Reconciliation
-- Failures                                : 0
--
-- INTERPRETATION:
-- Warehouse-level values reconcile with
-- month-wide portfolio totals calculated
-- through a separate SQL aggregation path.
--
-- Financial reconciliation tolerance:
-- 0.01 INR
--
-- =========================================================
-- C. VERIFIED BENCHMARK RECONCILIATION
-- =========================================================
--
-- October Warehouse Benchmark Failures   : 0
-- Twelve-Month Warehouse Benchmark
-- Failures                                : 0
--
-- October benchmarks were taken from
-- verified Section 05.1 outputs.
--
-- Twelve-month benchmarks were taken from
-- verified Section 05.3 outputs.
--
-- INTERPRETATION:
-- Previously documented warehouse results
-- remain reproducible using the current
-- MySQL inventory table.
--
-- =========================================================
-- D. FINAL QA RESULT
-- =========================================================
--
-- Months With Any QA Failure             : 0
--
-- Overall Warehouse QA Status            : PASS
--
-- =========================================================
-- E. COMPLETED SCRIPT 05 CHECKPOINTS
-- =========================================================
--
-- 05.1 October Warehouse KPIs            : PASSED
-- 05.2 Risk Rankings and Contributions   : PASSED
-- 05.3 Historical Warehouse Performance  : PASSED
-- 05.4 Final Warehouse Reconciliation    : PASSED
--
-- SCRIPT 05 STATUS:
-- COMPLETE FOR DATABASE-LEVEL ANALYSIS
--
-- =========================================================
-- F. CONFIRMED BUSINESS INVESTIGATION FINDINGS
-- =========================================================
--
-- OCTOBER OPERATIONAL CONCERN:
-- South
--
-- Evidence:
-- Lowest October Fill Rate = 92.04%
-- Highest October Stockout Rate = 25.00%
-- Most October Unfulfilled Units = 1331
--
-- HISTORICAL SERVICE CONCERN:
-- West
--
-- Evidence:
-- Twelve-month weighted Fill Rate = 93.54%
-- Lowest among the three warehouses.
--
-- OCTOBER FINANCIAL EXPOSURE:
-- West
--
-- Potential Margin Exposure:
-- 1129395.17 INR
--
-- HISTORICAL FINANCIAL EXPOSURE:
-- West
--
-- Cumulative Potential Margin Exposure:
-- 13013113.49 INR
--
-- HISTORICAL STOCKOUT OCCURRENCE:
-- South
--
-- Stockout Location-Month Occurrences:
-- 288
--
-- PREVENTIVE INVENTORY RISK:
-- North and West
--
-- October Positive-Stock At-Risk
-- Locations:
-- 48 each
--
-- IMPORTANT:
-- These are evidence-based investigation
-- priorities, not verified root causes.
--
-- =========================================================
-- G. VALIDATION LIMITATIONS
-- =========================================================
--
-- 1. Data represents a synthetic scenario.
--
-- 2. Warehouse and portfolio aggregation paths
--    use the same MySQL source table.
--
-- 3. Independent SQL-Python source verification
--    is still pending.
--
-- 4. Stockout location-month counts are not
--    distinct affected SKU-warehouse combinations
--    across the entire reporting period.
--
-- 5. Potential gross-margin exposure is an
--    estimated opportunity, not proven lost profit.
--
-- 6. Warehouse ranking does not establish
--    supplier or replenishment causality.
--
-- 7. Supplier-level and SKU-level investigations
--    are required before recommending actions.
--
-- =========================================================
-- H. NEXT SQL INVESTIGATIONS
-- =========================================================
--
-- SCRIPT 06:
-- Supplier Performance and Lead-Time Analysis
--
-- SCRIPT 07:
-- Inventory Risk and SKU Investigation
--
-- SCRIPT 08:
-- Financial Exposure Analysis
--
-- SCRIPT 09:
-- Independent SQL-Python Reconciliation
--
-- =========================================================
-- FINAL STATUS:
-- SCRIPT 05 DATABASE-LEVEL QA PASSED
-- =========================================================