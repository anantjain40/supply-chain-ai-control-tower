-- =========================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 07: INVENTORY RISK ANALYSIS
-- =========================================================
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- DATABASE:
-- supply_chain_ai_db
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- BUSINESS OBJECTIVE:
-- Identify SKU-level stockout, reorder,
-- inventory availability and unmet-demand risks.
--
-- SCRIPT SECTIONS:
-- 07.1 October Inventory Risk Classification
-- 07.2 SKU-Level Risk Ranking
-- 07.3 Reorder-Point Gap Investigation
-- 07.4 Recurring SKU-Warehouse Risk
-- 07.5 Final Inventory Risk QA
--
-- IMPORTANT:
-- Closing-stock classification and stockout
-- occurrence are distinct measures.
--
-- Potential margin exposure is not actual
-- realized lost profit.
--
-- =========================================================
-- SECTION 07.1: OCTOBER INVENTORY RISK CLASSIFICATION
-- =========================================================
--
-- BUSINESS QUESTION:
-- How many SKU-warehouse locations have zero
-- closing stock, positive stock below reorder
-- point, or healthy closing stock?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- GRAIN:
-- One SKU x Warehouse x Reporting Month
--
-- EXPECTED SOURCE ROWS:
-- 360 for October 2026
--
-- EXPECTED OUTPUT:
-- 3 inventory status groups
--
-- =========================================================

WITH october_locations AS (

    SELECT

        sku_id,

        warehouse,

        supplier_id,

        -- Closing-stock classification
        CASE

            WHEN closing_stock_units = 0
            THEN 'ZERO CLOSING STOCK'

            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
            THEN 'POSITIVE BELOW REORDER'

            ELSE 'HEALTHY CLOSING STOCK'

        END AS inventory_status,

        -- Stockout occurrence is tracked separately
        CASE

            WHEN stockout_days > 0
            THEN 1

            ELSE 0

        END AS stockout_occurred,

        -- Number of days with a recorded stockout
        stockout_days,

        -- Unfulfilled demand
        demand_units - fulfilled_units
            AS unfulfilled_units,

        -- Reorder-point gap for positive-stock
        -- at-risk locations only.
        CASE

            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units

            THEN reorder_point_units - closing_stock_units

            ELSE 0

        END AS reorder_gap_units,

        -- Potential gross-margin exposure.
        -- Uses the previously verified formula.
        (
            demand_units - fulfilled_units
        ) * GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS potential_margin_exposure

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

-- =========================================================
-- STEP 2: AGGREGATE BY CLOSING-STOCK CATEGORY
-- =========================================================

inventory_summary AS (

    SELECT

        inventory_status,

        COUNT(*) AS location_count,

        SUM(stockout_occurred)
            AS locations_with_stockout,

        SUM(stockout_days)
            AS total_stockout_days,

        SUM(
            CASE
                WHEN unfulfilled_units > 0
                THEN 1 ELSE 0
            END
        ) AS locations_with_unfulfilled_demand,

        SUM(unfulfilled_units)
            AS unfulfilled_units,

        SUM(reorder_gap_units)
            AS reorder_gap_units,

        SUM(potential_margin_exposure)
            AS potential_margin_exposure_inr

    FROM october_locations

    GROUP BY inventory_status

)

-- =========================================================
-- STEP 3: FINAL INVENTORY STATUS SCORECARD
-- =========================================================

SELECT

    inventory_status,

    location_count,

    -- Share of all October SKU-warehouse locations
    ROUND(
        location_count * 100.0 /
        NULLIF(
            SUM(location_count) OVER (),
            0
        ),
        2
    ) AS portfolio_location_share_pct,

    locations_with_stockout,

    -- Stockout occurrence rate within category
    ROUND(
        locations_with_stockout * 100.0 /
        NULLIF(location_count, 0),
        2
    ) AS group_stockout_rate_pct,

    total_stockout_days,

    locations_with_unfulfilled_demand,

    unfulfilled_units,

    reorder_gap_units,

    ROUND(
        potential_margin_exposure_inr,
        2
    ) AS potential_margin_exposure_inr

FROM inventory_summary

ORDER BY FIELD(
    inventory_status,
    'ZERO CLOSING STOCK',
    'POSITIVE BELOW REORDER',
    'HEALTHY CLOSING STOCK'
);
-- =========================================================
-- SECTION 07.1: VERIFIED OCTOBER INVENTORY RISK
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING MONTH:
-- October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- OUTPUT:
-- 3 Inventory Status Rows x 10 Columns
--
-- VALIDATION STATUS:
-- PASSED - Matched verified October KPIs.
--
-- =========================================================
-- A. INVENTORY CLASSIFICATION
-- =========================================================
--
-- Inventory Locations            : 360
--
-- ZERO CLOSING STOCK:
-- Locations                      : 79
-- Portfolio Share                : 21.94%
--
-- POSITIVE BELOW REORDER:
-- Locations                      : 141
-- Portfolio Share                : 39.17%
--
-- HEALTHY CLOSING STOCK:
-- Locations                      : 140
-- Portfolio Share                : 38.89%
--
-- Location Reconciliation:
-- 79 + 141 + 140 = 360
--
-- Portfolio Share Reconciliation:
-- 21.94 + 39.17 + 38.89 = 100.00%
--
-- =========================================================
-- B. ZERO CLOSING STOCK RESULTS
-- =========================================================
--
-- Total Locations                : 79
-- Locations With Stockouts       : 79
-- Group Stockout Rate            : 100.00%
--
-- Total Stockout Days            : 751
--
-- Locations With Unmet Demand    : 79
-- Unfulfilled Units              : 3681
--
-- Positive-Stock Reorder Gap     : 0 units
--
-- Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- INTERPRETATION:
-- In this synthetic October dataset,
-- all 79 zero-closing-stock locations
-- experienced stockouts and unmet demand.
--
-- All recorded October unfulfilled units
-- and potential margin exposure are
-- concentrated in this category.
--
-- =========================================================
-- C. POSITIVE STOCK BELOW REORDER
-- =========================================================
--
-- Total Locations                : 141
-- Portfolio Share                : 39.17%
--
-- Locations With Stockouts       : 0
-- Total Stockout Days            : 0
--
-- Locations With Unmet Demand    : 0
-- Unfulfilled Units              : 0
--
-- Total Reorder-Point Gap        : 4544 units
--
-- Potential Margin Exposure      : INR 0.00
--
-- INTERPRETATION:
-- These locations retain positive stock,
-- but their closing quantities are below
-- their assigned reorder points.
--
-- They represent preventive inventory risk.
--
-- Reorder-point gap is not automatically
-- the recommended purchase order quantity.
--
-- =========================================================
-- D. HEALTHY CLOSING STOCK
-- =========================================================
--
-- Total Locations                : 140
-- Portfolio Share                : 38.89%
--
-- Locations With Stockouts       : 0
-- Total Stockout Days            : 0
--
-- Locations With Unmet Demand    : 0
-- Unfulfilled Units              : 0
--
-- Positive-Stock Reorder Gap     : 0 units
--
-- Potential Margin Exposure      : INR 0.00
--
-- INTERPRETATION:
-- Closing stock meets or exceeds
-- the assigned reorder point.
--
-- No October shortages were recorded
-- for this category in the analyzed data.
--
-- =========================================================
-- E. COMPANY-WIDE RECONCILIATION
-- =========================================================
--
-- Total Inventory Locations      : 360
-- Total Stockout Locations       : 79
-- Total Stockout Days            : 751
--
-- Total Unfulfilled Units        : 3681
--
-- Positive-Stock Reorder Gap     : 4544 units
--
-- Total Potential Margin Exposure:
-- INR 3071205.83
--
-- Verified historical references:
--
-- 03_business_kpis.sql
-- 05_warehouse_analysis.sql
-- 06_supplier_performance.sql
--
-- Relevant October portfolio totals matched.
--
-- =========================================================
-- F. INVENTORY RISK DEFINITIONS
-- =========================================================
--
-- ZERO CLOSING STOCK:
-- closing_stock_units = 0
--
-- POSITIVE BELOW REORDER:
-- closing_stock_units > 0
-- AND closing_stock_units < reorder_point_units
--
-- HEALTHY CLOSING STOCK:
-- closing_stock_units >= reorder_point_units
--
-- STOCKOUT OCCURRENCE:
-- stockout_days > 0
--
-- UNFULFILLED UNITS:
-- demand_units - fulfilled_units
--
-- POSITIVE-STOCK REORDER GAP:
-- reorder_point_units - closing_stock_units
--
-- Applied only when closing stock is
-- positive and below the reorder point.
--
-- POTENTIAL GROSS-MARGIN EXPOSURE:
-- Unfulfilled Units
-- * GREATEST(Unit Selling Price - Unit Cost, 0)
--
-- =========================================================
-- G. KEY BUSINESS FINDINGS
-- =========================================================
--
-- 1. All 79 October stockout locations
--    fall within the zero-closing-stock category.
--
-- 2. All 3681 unfulfilled units are associated
--    with these 79 locations.
--
-- 3. Estimated potential gross-margin exposure
--    totals INR 3071205.83.
--
-- 4. Another 141 locations have positive stock
--    below their assigned reorder points.
--
-- 5. Their combined positive-stock reorder gap
--    is 4544 units.
--
-- 6. The remaining 140 locations have healthy
--    closing stock relative to reorder thresholds.
--
-- =========================================================
-- H. OPERATIONAL INVESTIGATION PRIORITIES
-- =========================================================
--
-- PRIORITY 1: OBSERVED SHORTAGES
--
-- Review the 79 zero-closing-stock locations
-- with recorded stockouts and unmet demand.
--
-- PRIORITY 2: PREVENTIVE REPLENISHMENT
--
-- Review the 141 locations below reorder point.
--
-- PRIORITY 3: NORMAL MONITORING
--
-- Continue monitoring the 140 locations
-- with closing stock meeting reorder thresholds.
--
-- These are investigation groups rather
-- than a validated purchase-order schedule.
--
-- =========================================================
-- I. LIMITATIONS
-- =========================================================
--
-- 1. Dataset represents a synthetic business.
--
-- 2. Stockout occurrence and zero closing
--    stock are conceptually distinct measures.
--
-- 3. Their exact overlap in October is a
--    property of this dataset, not a
--    universal inventory rule.
--
-- 4. The 4544-unit gap includes only
--    positive-stock locations below reorder.
--    Zero-stock shortfalls are not included.
--
-- 5. Reorder gaps do not represent final
--    purchase order quantities.
--
-- 6. Potential gross-margin exposure is
--    not confirmed realized profit loss.
--
-- 7. SKU-level investigation and recurrence
--    analysis remain pending.
--
-- =========================================================
-- SECTION 07.1 STATUS:
-- VERIFIED
--
-- NEXT:
-- SECTION 07.2 - SKU-LEVEL RISK RANKING
-- =========================================================
-- =========================================================
-- SECTION 07.2: SKU-LEVEL STOCKOUT & FINANCIAL
--               RISK RANKINGS
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING MONTH:
-- October 2026
--
-- BUSINESS QUESTIONS:
-- 1. Which SKU-warehouse locations have the
--    greatest potential financial exposure?
-- 2. Which locations have most unfulfilled demand?
-- 3. Which locations have longest stockout duration?
-- 4. How concentrated is total financial exposure?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- GRAIN:
-- One SKU x Warehouse x Reporting Month
--
-- ANALYSIS:
-- All October shortage locations.
--
-- DISPLAY:
-- Top 15 locations by potential margin exposure.
--
-- IMPORTANT:
-- Rankings are calculated before LIMIT.
-- No arbitrary composite risk score is used.
-- =========================================================


WITH october_inventory AS (

    SELECT

        sku_id,

        product_name,

        category,

        warehouse,

        supplier_id,

        demand_units,

        fulfilled_units,

        closing_stock_units,

        stockout_days,

        -- Unfulfilled customer demand
        demand_units - fulfilled_units
            AS unfulfilled_units,

        -- Nonnegative estimated unit gross margin
        GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS unit_gross_margin_inr,

        -- Potential gross-margin exposure
        (demand_units - fulfilled_units)
        * GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

-- =========================================================
-- STEP 2: IDENTIFY SHORTAGE LOCATIONS
-- =========================================================

shortage_locations AS (

    SELECT *

    FROM october_inventory

    WHERE stockout_days > 0
       OR unfulfilled_units > 0

),

-- =========================================================
-- STEP 3: CALCULATE PORTFOLIO TOTALS & RANKINGS
-- =========================================================

shortage_rankings AS (

    SELECT

        shortage_locations.*,

        -- Number of shortage locations
        COUNT(*) OVER ()
            AS portfolio_shortage_locations,

        -- Total unfulfilled demand
        SUM(unfulfilled_units) OVER ()
            AS portfolio_unfulfilled_units,

        -- Total stockout days
        SUM(stockout_days) OVER ()
            AS portfolio_stockout_days,

        -- Total potential margin exposure
        SUM(potential_margin_exposure_inr) OVER ()
            AS portfolio_margin_exposure_inr,

        -- Highest financial exposure gets Rank 1
        DENSE_RANK() OVER (

            ORDER BY
                potential_margin_exposure_inr DESC

        ) AS financial_exposure_rank,

        -- Most unfulfilled units gets Rank 1
        DENSE_RANK() OVER (

            ORDER BY
                unfulfilled_units DESC

        ) AS unfulfilled_demand_rank,

        -- Longest stockout duration gets Rank 1
        DENSE_RANK() OVER (

            ORDER BY
                stockout_days DESC

        ) AS stockout_duration_rank,

        -- Cumulative financial exposure.
        -- Deterministic ordering handles tied values.
        SUM(potential_margin_exposure_inr) OVER (

            ORDER BY
                potential_margin_exposure_inr DESC,
                sku_id,
                warehouse

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS cumulative_margin_exposure_inr

    FROM shortage_locations

)

-- =========================================================
-- STEP 4: DISPLAY TOP 15 FINANCIAL-RISK LOCATIONS
-- =========================================================

SELECT

    sku_id,

    product_name,

    category,

    warehouse,

    supplier_id,

    unfulfilled_units,

    stockout_days,

    ROUND(
        unit_gross_margin_inr,
        2
    ) AS unit_gross_margin_inr,

    ROUND(
        potential_margin_exposure_inr,
        2
    ) AS potential_margin_exposure_inr,

    -- Individual share of portfolio financial exposure
    ROUND(
        potential_margin_exposure_inr * 100.0 /
        NULLIF(portfolio_margin_exposure_inr, 0),
        2
    ) AS margin_exposure_share_pct,

    -- Cumulative share after including this location
    ROUND(
        cumulative_margin_exposure_inr * 100.0 /
        NULLIF(portfolio_margin_exposure_inr, 0),
        2
    ) AS cumulative_margin_share_pct,

    financial_exposure_rank,

    unfulfilled_demand_rank,

    stockout_duration_rank,

    -- Reconciliation benchmarks
    portfolio_shortage_locations,

    portfolio_unfulfilled_units,

    portfolio_stockout_days,

    ROUND(
        portfolio_margin_exposure_inr,
        2
    ) AS portfolio_margin_exposure_inr

FROM shortage_rankings

ORDER BY
    potential_margin_exposure_inr DESC,
    sku_id,
    warehouse

LIMIT 15;
-- =========================================================
-- SECTION 07.2: VERIFIED SKU-LEVEL RISK RANKINGS
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING MONTH:
-- October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- OUTPUT:
-- Top 15 SKU-Warehouse Locations x 18 Columns
--
-- VALIDATION STATUS:
-- PASSED - Rankings, cumulative contributions
-- and portfolio benchmarks reconciled.
--
-- =========================================================
-- A. PORTFOLIO RECONCILIATION
-- =========================================================
--
-- Total Inventory Locations       : 360
-- Total Shortage Locations        : 79
--
-- Portfolio Unfulfilled Units     : 3681
-- Portfolio Stockout Days         : 751
--
-- Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- All displayed portfolio totals match
-- the previously verified October KPIs.
--
-- =========================================================
-- B. TOP 15 FINANCIAL EXPOSURE LOCATIONS
-- =========================================================
--
-- Rank  SKU      Warehouse  Supplier  Margin Exposure INR
--
-- 01    SKU0051  South      SUP005          303759.72
-- 02    SKU0051  West       SUP005          291486.60
-- 03    SKU0043  North      SUP005          155298.40
-- 04    SKU0109  West       SUP011          152360.28
-- 05    SKU0111  North      SUP011          151948.80
-- 06    SKU0107  North      SUP011          138416.58
-- 07    SKU0108  West       SUP012          107346.06
-- 08    SKU0104  North      SUP012          105629.16
-- 09    SKU0054  South      SUP006           91433.95
-- 10    SKU0060  South      SUP006           81303.04
-- 11    SKU0006  West       SUP002           80890.19
-- 12    SKU0041  West       SUP005           79977.50
-- 13    SKU0120  West       SUP012           74141.53
-- 14    SKU0088  West       SUP010           73063.76
-- 15    SKU0007  South      SUP001           59424.42
--
-- Financial ranks 1-15 were verified.
--
-- IMPORTANT:
-- One SKU can appear in multiple warehouses.
-- Rankings use SKU-Warehouse locations,
-- not distinct SKU identifiers alone.
--
-- =========================================================
-- C. CUMULATIVE FINANCIAL EXPOSURE
-- =========================================================
--
-- TOP 1 LOCATION:
-- Exposure INR                  : 303759.72
-- Portfolio Contribution        : 9.89%
--
-- TOP 2 LOCATIONS:
-- Exposure INR                  : 595246.32
-- Portfolio Contribution        : 19.38%
--
-- TOP 5 LOCATIONS:
-- Exposure INR                  : 1054853.80
-- Portfolio Contribution        : 34.35%
--
-- TOP 10 LOCATIONS:
-- Exposure INR                  : 1578982.59
-- Portfolio Contribution        : 51.41%
--
-- TOP 15 LOCATIONS:
-- Exposure INR                  : 1946479.99
-- Portfolio Contribution        : 63.38%
--
-- Top 15 Unfulfilled Units      : 1779
-- Share of Portfolio Units      : 48.33%
--
-- Top 15 Stockout Location-Days : 316
-- Share of Portfolio Days       : 42.08%
--
-- INTERPRETATION:
-- A relatively small number of shortage
-- locations represents a substantial share
-- of estimated financial exposure.
--
-- =========================================================
-- D. SKU0051: FINANCIAL INVESTIGATION PRIORITY
-- =========================================================
--
-- SKU:
-- SKU0051
--
-- Product:
-- Home & Living Product 11
--
-- Supplier:
-- SUP005
--
-- SOUTH WAREHOUSE:
-- Unfulfilled Units             : 198
-- Stockout Days                 : 30
-- Unit Gross Margin INR         : 1534.14
-- Potential Exposure INR        : 303759.72
-- Financial Exposure Rank       : 1
--
-- WEST WAREHOUSE:
-- Unfulfilled Units             : 190
-- Stockout Days                 : 31
-- Unit Gross Margin INR         : 1534.14
-- Potential Exposure INR        : 291486.60
-- Financial Exposure Rank       : 2
--
-- COMBINED:
-- Unfulfilled Units             : 388
-- Stockout Location-Days        : 61
-- Potential Exposure INR        : 595246.32
-- Portfolio Exposure Share      : 19.38%
--
-- NOTE:
-- 61 represents summed location-days across
-- two warehouses, not 61 calendar days.
--
-- BUSINESS INVESTIGATION:
-- Review replenishment, demand, availability
-- and incoming supply for SKU0051 separately
-- in South and West.
--
-- =========================================================
-- E. SUP005 FINANCIAL CONCENTRATION
-- =========================================================
--
-- SUP005 TOP-15 REPRESENTED LOCATIONS:
--
-- SKU0051 South      : 303759.72
-- SKU0051 West       : 291486.60
-- SKU0043 North      : 155298.40
-- SKU0041 West       :  79977.50
--
-- Combined Exposure INR:
-- 830522.22
--
-- Total SUP005 October Exposure INR:
-- 952652.45
--
-- Share of SUP005 Exposure:
-- 830522.22 / 952652.45 * 100
-- = 87.18%
--
-- INTERPRETATION:
-- Four SKU-Warehouse locations represent
-- 87.18% of SUP005's October potential
-- gross-margin exposure.
--
-- =========================================================
-- F. DEMAND VOLUME VS FINANCIAL EXPOSURE
-- =========================================================
--
-- SKU0041 - WEST:
-- Unfulfilled Units             : 250
-- Unit Gross Margin INR         : 319.91
-- Potential Exposure INR        : 79977.50
-- Financial Rank                : 12
-- Unfulfilled Demand Rank       : 1
--
-- SKU0108 - WEST:
-- Unfulfilled Units             : 43
-- Unit Gross Margin INR         : 2496.42
-- Potential Exposure INR        : 107346.06
-- Financial Rank                : 7
-- Unfulfilled Demand Rank       : 23
--
-- INTERPRETATION:
-- Higher unfulfilled unit volume does not
-- always produce higher financial exposure.
--
-- Unit gross margins must also be considered.
--
-- =========================================================
-- G. INDEPENDENT RANKING DEFINITIONS
-- =========================================================
--
-- FINANCIAL EXPOSURE RANK:
-- Highest potential gross-margin exposure
-- receives Rank 1.
--
-- UNFULFILLED DEMAND RANK:
-- Highest unfulfilled unit count
-- receives Rank 1.
--
-- STOCKOUT DURATION RANK:
-- Highest stockout-day count
-- receives Rank 1.
--
-- DENSE_RANK() preserves ties.
--
-- No arbitrary composite risk score was used.
--
-- =========================================================
-- H. SQL METHODS
-- =========================================================
--
-- COUNT(*) OVER():
-- Calculates all shortage locations.
--
-- SUM(metric) OVER():
-- Calculates portfolio shortage totals.
--
-- DENSE_RANK():
-- Produces independent risk rankings.
--
-- SUM(exposure) OVER (
--     ORDER BY exposure DESC, sku_id, warehouse
--     ROWS BETWEEN UNBOUNDED PRECEDING
--                  AND CURRENT ROW
-- ):
-- Calculates cumulative financial exposure.
--
-- LIMIT 15:
-- Displays the 15 largest financial-exposure
-- locations after full-population ranking.
--
-- =========================================================
-- I. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business dataset.
--
-- 2. Results are for October 2026.
--
-- 3. Rankings use SKU-Warehouse locations.
--
-- 4. A repeated SKU in different warehouses
--    represents separate location-level risks.
--
-- 5. Potential gross-margin exposure assumes
--    estimated unit gross margin on unmet units.
--
-- 6. Estimated exposure is not confirmed
--    lost profit or guaranteed recoverable value.
--
-- 7. Financial exposure does not automatically
--    determine replenishment feasibility.
--
-- 8. Historical recurrence is not yet
--    evaluated in this section.
--
-- =========================================================
-- SECTION 07.2 VALIDATION STATUS:
-- PASSED
--
-- NEXT:
-- SECTION 07.3 - REORDER-POINT GAP INVESTIGATION
-- =========================================================
-- =========================================================
-- SECTION 07.3: REORDER-POINT GAP &
--               PREVENTIVE REPLENISHMENT ANALYSIS
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING MONTH:
-- October 2026
--
-- BUSINESS QUESTIONS:
-- 1. Which SKU-warehouse locations have
--    the largest reorder-point gaps?
--
-- 2. How much stock remains at each location?
--
-- 3. How many days might closing stock cover
--    using October's average daily demand?
--
-- 4. Is indicative coverage below the
--    observed supplier lead time?
--
-- 5. How concentrated are reorder gaps?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- GRAIN:
-- One SKU x Warehouse x Reporting Month
--
-- ANALYSIS POPULATION:
-- Positive closing stock below reorder point.
--
-- EXPECTED POPULATION:
-- 141 locations, 4544 reorder-gap units.
--
-- DISPLAY:
-- Top 15 locations by reorder-gap units.
--
-- IMPORTANT:
-- Reorder gap is not an automatic PO quantity.
-- Coverage is indicative, not a forecast.
-- =========================================================


WITH october_reorder_base AS (

    SELECT

        reporting_month,

        sku_id,

        product_name,

        category,

        warehouse,

        supplier_id,

        closing_stock_units,

        reorder_point_units,

        demand_units,

        supplier_deliveries_count,

        replenishment_lead_time_days,

        -- Unit shortfall to reorder threshold
        reorder_point_units - closing_stock_units
            AS reorder_gap_units,

        -- Percentage below reorder point
        (
            reorder_point_units - closing_stock_units
        ) * 100.0 /
        NULLIF(reorder_point_units, 0)
            AS reorder_gap_pct,

        -- October average daily demand
        demand_units * 1.0 /
        DAY(LAST_DAY(reporting_month))
            AS avg_daily_demand_units,

        -- Indicative days of closing-stock coverage
        closing_stock_units
        * DAY(LAST_DAY(reporting_month)) * 1.0 /
        NULLIF(demand_units, 0)
            AS indicative_stock_cover_days,

        -- Use observed lead time only when there
        -- were deliveries and the value is known.
        CASE

            WHEN supplier_deliveries_count > 0
             AND replenishment_lead_time_days IS NOT NULL

            THEN replenishment_lead_time_days

            ELSE NULL

        END AS observed_lead_time_days

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

      AND closing_stock_units > 0

      AND closing_stock_units < reorder_point_units

),

-- =========================================================
-- STEP 2: PORTFOLIO REORDER-GAP TOTALS AND RANKINGS
-- =========================================================

reorder_rankings AS (

    SELECT

        october_reorder_base.*,

        -- Total below-reorder locations
        COUNT(*) OVER ()
            AS portfolio_below_reorder_locations,

        -- Total reorder-gap units
        SUM(reorder_gap_units) OVER ()
            AS portfolio_reorder_gap_units,

        -- Largest reorder gap = Rank 1
        DENSE_RANK() OVER (

            ORDER BY reorder_gap_units DESC

        ) AS reorder_gap_rank,

        -- Running reorder-gap total
        SUM(reorder_gap_units) OVER (

            ORDER BY
                reorder_gap_units DESC,
                demand_units DESC,
                sku_id,
                warehouse

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS cumulative_reorder_gap_units

    FROM october_reorder_base

)

-- =========================================================
-- STEP 3: TOP 15 PREVENTIVE REPLENISHMENT CANDIDATES
-- =========================================================

SELECT

    sku_id,

    product_name,

    category,

    warehouse,

    supplier_id,

    closing_stock_units,

    reorder_point_units,

    reorder_gap_units,

    ROUND(
        reorder_gap_pct,
        2
    ) AS reorder_gap_pct,

    demand_units,

    ROUND(
        avg_daily_demand_units,
        2
    ) AS avg_daily_demand_units,

    ROUND(
        indicative_stock_cover_days,
        2
    ) AS indicative_stock_cover_days,

    observed_lead_time_days,

    -- Negative result means indicative coverage
    -- is shorter than the observed lead time.
    ROUND(
        indicative_stock_cover_days
        - observed_lead_time_days,
        2
    ) AS coverage_minus_lead_days,

    -- Only compare when both observations exist.
    CASE

        WHEN indicative_stock_cover_days IS NULL
          OR observed_lead_time_days IS NULL

        THEN 'INSUFFICIENT DATA'

        WHEN indicative_stock_cover_days
             < observed_lead_time_days

        THEN 'COVERAGE BELOW OBSERVED LEAD'

        ELSE 'COVERAGE AT/ABOVE OBSERVED LEAD'

    END AS lead_time_comparison,

    reorder_gap_rank,

    -- Individual share of all reorder-gap units
    ROUND(
        reorder_gap_units * 100.0 /
        NULLIF(portfolio_reorder_gap_units, 0),
        2
    ) AS reorder_gap_share_pct,

    -- Cumulative share of all reorder-gap units
    ROUND(
        cumulative_reorder_gap_units * 100.0 /
        NULLIF(portfolio_reorder_gap_units, 0),
        2
    ) AS cumulative_gap_share_pct,

    -- Portfolio reconciliation fields
    portfolio_below_reorder_locations,

    portfolio_reorder_gap_units

FROM reorder_rankings

ORDER BY
    reorder_gap_units DESC,
    demand_units DESC,
    sku_id,
    warehouse

LIMIT 15;
-- =========================================================
-- SECTION 07.3: VERIFIED REORDER-POINT GAP
--               & PREVENTIVE REPLENISHMENT ANALYSIS
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- REPORTING MONTH:
-- October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- VALIDATION STATUS:
-- PASSED - Source benchmarks, ranking, coverage
-- calculations and cumulative contributions.
--
-- =========================================================
-- A. PORTFOLIO RECONCILIATION
-- =========================================================
--
-- October Inventory Locations       : 360
--
-- Positive-Stock Below-Reorder      : 141
-- Portfolio Location Share          : 39.17%
--
-- Total Positive-Stock Reorder Gap  : 4544 units
--
-- Displayed Locations               : 15
-- Displayed Columns                 : 20
--
-- Top-15 Reorder Gap                : 1309 units
-- Top-15 Portfolio Gap Share        : 28.81%
--
-- Remaining Locations               : 126
-- Remaining Gap Units               : 3235
--
-- These totals reconcile with the
-- verified Section 07.1 results.
--
-- =========================================================
-- B. TOP 15 REORDER-GAP LOCATIONS
-- =========================================================
--
-- SKU      Warehouse  Supplier  Gap  Cover  Lead
--
-- SKU0076  South      SUP008    133   0.53    12
-- SKU0008  West       SUP002    116   0.70    12
-- SKU0083  South      SUP009    116   0.15    14
-- SKU0071  South      SUP007    102   0.48    18
-- SKU0087  West       SUP009     93   0.92    13
-- SKU0034  West       SUP004     90   3.80    19
-- SKU0055  North      SUP005     86   5.60    14
-- SKU0032  South      SUP004     86   0.99    13
-- SKU0060  North      SUP006     80   0.14     8
-- SKU0043  South      SUP005     79   2.01    13
-- SKU0079  South      SUP007     75   3.85    11
-- SKU0055  South      SUP005     65   8.41    13
-- SKU0097  South      SUP009     64   9.54    15
-- SKU0031  South      SUP003     62   0.31     5
-- SKU0001  South      SUP001     62   1.72    12
--
-- Cover and Lead are measured in days.
--
-- All 15 locations have indicative stock
-- coverage below observed lead time.
--
-- =========================================================
-- C. CUMULATIVE REORDER-GAP CONTRIBUTION
-- =========================================================
--
-- Top 1 Location:
-- Gap Units                       : 133
-- Portfolio Share                 : 2.93%
--
-- Top 2 Locations:
-- Gap Units                       : 249
-- Portfolio Share                 : 5.48%
--
-- Top 3 Locations:
-- Gap Units                       : 365
-- Portfolio Share                 : 8.03%
--
-- Top 5 Locations:
-- Gap Units                       : 560
-- Portfolio Share                 : 12.32%
--
-- Top 10 Locations:
-- Gap Units                       : 981
-- Portfolio Share                 : 21.59%
--
-- Top 15 Locations:
-- Gap Units                       : 1309
-- Portfolio Share                 : 28.81%
--
-- INTERPRETATION:
-- Reorder gaps are distributed across
-- a substantial number of locations.
--
-- The top 15 represent less than one-third
-- of the total positive-stock reorder gap.
--
-- =========================================================
-- D. SKU0076: LARGEST ABSOLUTE REORDER GAP
-- =========================================================
--
-- SKU                              : SKU0076
-- Warehouse                        : South
-- Supplier                         : SUP008
--
-- Closing Stock                    : 4 units
-- Reorder Point                    : 137 units
--
-- Reorder Gap:
-- 137 - 4 = 133 units
--
-- Reorder Gap Percentage           : 97.08%
--
-- October Demand                   : 236 units
-- Average Daily Demand             : 7.61 units
--
-- Indicative Stock Coverage        : 0.53 days
-- Observed Lead Time               : 12 days
--
-- Coverage Minus Lead Time         : -11.47 days
--
-- Reorder Gap Rank                 : 1
--
-- BUSINESS INVESTIGATION:
-- Review current available stock, open orders,
-- expected replenishment timing and demand.
--
-- =========================================================
-- E. SKU0071: LARGEST COVERAGE DEFICIT
-- =========================================================
--
-- SKU                              : SKU0071
-- Warehouse                        : South
-- Supplier                         : SUP007
--
-- Closing Stock                    : 3 units
-- Reorder Point                    : 105 units
-- Reorder Gap                      : 102 units
--
-- Indicative Coverage              : 0.48 days
-- Observed Lead Time               : 18 days
--
-- Coverage Minus Lead Time         : -17.52 days
--
-- INTERPRETATION:
-- Largest negative coverage-to-lead-time
-- difference among the top 15 locations.
--
-- This is an investigation signal,
-- not a guaranteed future stockout.
--
-- =========================================================
-- F. SKU0083: LARGEST PERCENTAGE GAP
-- =========================================================
--
-- SKU                              : SKU0083
-- Warehouse                        : South
-- Supplier                         : SUP009
--
-- Closing Stock                    : 1 unit
-- Reorder Point                    : 117 units
--
-- Reorder Gap                      : 116 units
-- Reorder Gap Percentage           : 99.15%
--
-- Indicative Coverage              : 0.15 days
-- Observed Lead Time               : 14 days
--
-- Coverage Minus Lead Time         : -13.85 days
--
-- INTERPRETATION:
-- Highest proportional reorder-point shortfall
-- among the displayed top 15 locations.
--
-- =========================================================
-- G. TOP-15 WAREHOUSE DISTRIBUTION
-- =========================================================
--
-- SOUTH:
-- Locations                        : 10
-- Gap Units                        : 844
-- Share of Top-15 Gap              : 64.48%
--
-- WEST:
-- Locations                        : 3
-- Gap Units                        : 299
-- Share of Top-15 Gap              : 22.84%
--
-- NORTH:
-- Locations                        : 2
-- Gap Units                        : 166
-- Share of Top-15 Gap              : 12.68%
--
-- Reconciliation:
-- 844 + 299 + 166 = 1309 units
--
-- IMPORTANT:
-- These figures describe only the top 15.
-- They are not full-portfolio warehouse totals.
--
-- =========================================================
-- H. CROSS-WAREHOUSE RISK OBSERVATIONS
-- =========================================================
--
-- SKU0043:
--
-- North - October observed shortage:
-- 170 unfulfilled units.
--
-- South - Positive-stock reorder risk:
-- 79 units below reorder point.
--
-- SKU0060:
--
-- South - October observed shortage:
-- 182 unfulfilled units.
--
-- North - Positive-stock reorder risk:
-- 80 units below reorder point.
--
-- BUSINESS INTERPRETATION:
-- A SKU may have different inventory conditions
-- in different warehouses.
--
-- Review warehouse-specific demand,
-- replenishment and available stock.
--
-- Transfers are not yet recommended without
-- checking operational feasibility.
--
-- =========================================================
-- I. SQL METHODS
-- =========================================================
--
-- REORDER GAP:
-- reorder_point_units - closing_stock_units
--
-- REORDER GAP PERCENTAGE:
-- reorder_gap_units / reorder_point_units * 100
--
-- OCTOBER AVERAGE DAILY DEMAND:
-- demand_units / 31
--
-- INDICATIVE STOCK COVERAGE:
-- closing_stock_units / avg_daily_demand_units
--
-- COVERAGE MINUS LEAD TIME:
-- indicative_stock_cover_days
-- - observed_lead_time_days
--
-- DENSE_RANK():
-- Ranks absolute reorder-gap units.
--
-- SUM(...) OVER():
-- Computes the full-population gap.
--
-- CUMULATIVE SUM WINDOW:
-- Computes running reorder-gap contribution.
--
-- LIMIT 15:
-- Displays the leading reorder-gap locations
-- after full-population calculations.
--
-- =========================================================
-- J. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business dataset.
--
-- 2. Results cover October 2026 only.
--
-- 3. October average demand is not a
--    validated future demand forecast.
--
-- 4. Observed historical lead time is
--    not a guaranteed future lead time.
--
-- 5. Open purchase orders and expected
--    receipt dates are not incorporated.
--
-- 6. Reorder-point gaps are not approved
--    purchase-order quantities.
--
-- 7. Coverage below observed lead time
--    does not prove a future stockout.
--
-- 8. The 15/15 coverage finding applies
--    to the displayed shortlist only.
--
-- 9. Full-portfolio warehouse and supplier
--    distributions require separate analysis.
--
-- =========================================================
-- SECTION 07.3 VALIDATION STATUS:
-- PASSED
--
-- NEXT:
-- SECTION 07.4 - RECURRING SKU-WAREHOUSE RISK
-- =========================================================
-- =========================================================
-- SECTION 07.4: RECURRING SKU-WAREHOUSE INVENTORY RISK
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
-- 1. Which SKU-warehouse locations experience
--    repeated stockouts?
--
-- 2. Which locations are persistently below
--    their reorder thresholds?
--
-- 3. How much historical unfulfilled demand
--    and potential margin exposure is involved?
--
-- 4. Have shortages occurred recently?
--
-- 5. What is each location's October status?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- GRAIN:
-- One SKU x Warehouse x Reporting Month
--
-- EXPECTED ANALYSIS:
-- 4320 records across 360 unique locations.
--
-- OUTPUT:
-- Top 15 locations by stockout recurrence,
-- followed by historical unfulfilled demand
-- and potential margin exposure.
--
-- IMPORTANT:
-- Historical recurrence does not prove
-- that a future stockout will occur.
-- =========================================================


WITH monthly_inventory AS (

    SELECT

        reporting_month,

        sku_id,

        product_name,

        category,

        warehouse,

        supplier_id,

        stockout_days,

        -- Did this location experience
        -- a stockout during this month?
        CASE
            WHEN stockout_days > 0
            THEN 1 ELSE 0
        END AS stockout_flag,

        -- Did it finish the month at zero stock?
        CASE
            WHEN closing_stock_units = 0
            THEN 1 ELSE 0
        END AS zero_closing_stock_flag,

        -- Positive stock below reorder point
        CASE
            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
            THEN 1 ELSE 0
        END AS below_reorder_flag,

        -- Closing stock meets reorder threshold
        CASE
            WHEN closing_stock_units >= reorder_point_units
            THEN 1 ELSE 0
        END AS healthy_stock_flag,

        -- Closing-stock classification
        CASE

            WHEN closing_stock_units = 0
            THEN 'ZERO CLOSING STOCK'

            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
            THEN 'POSITIVE BELOW REORDER'

            ELSE 'HEALTHY CLOSING STOCK'

        END AS inventory_status,

        -- Unfulfilled demand in this month
        demand_units - fulfilled_units
            AS unfulfilled_units,

        -- Estimated potential gross-margin exposure
        (
            demand_units - fulfilled_units
        ) * GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month BETWEEN
        '2025-11-01' AND '2026-10-01'

),

-- =========================================================
-- STEP 2: CREATE TWELVE-MONTH LOCATION HISTORY
-- =========================================================

location_history AS (

    SELECT

        sku_id,

        warehouse,

        MAX(product_name) AS product_name,

        MAX(category) AS category,

        MAX(supplier_id) AS supplier_id,

        -- Distinct months with records
        COUNT(DISTINCT reporting_month)
            AS months_observed,

        -- Months with at least one stockout day
        SUM(stockout_flag)
            AS stockout_months,

        -- Months ending with zero closing stock
        SUM(zero_closing_stock_flag)
            AS zero_closing_stock_months,

        -- Months ending with positive stock
        -- below reorder point
        SUM(below_reorder_flag)
            AS below_reorder_months,

        -- Months ending healthy
        SUM(healthy_stock_flag)
            AS healthy_months,

        -- Total days with recorded stockouts
        SUM(stockout_days)
            AS historical_stockout_days,

        -- Months with positive unmet demand
        SUM(
            CASE
                WHEN unfulfilled_units > 0
                THEN 1 ELSE 0
            END
        ) AS months_with_unfulfilled_demand,

        -- Historical unfulfilled demand
        SUM(unfulfilled_units)
            AS historical_unfulfilled_units,

        -- Historical estimated financial exposure
        SUM(potential_margin_exposure_inr)
            AS historical_margin_exposure_inr,

        -- Stockout months in Aug, Sep and Oct 2026
        SUM(
            CASE
                WHEN reporting_month BETWEEN
                     '2026-08-01' AND '2026-10-01'
                THEN stockout_flag
                ELSE 0
            END
        ) AS recent_3m_stockout_months,

        -- October closing-stock status
        MAX(
            CASE
                WHEN reporting_month = '2026-10-01'
                THEN inventory_status
                ELSE NULL
            END
        ) AS october_inventory_status,

        -- October unfulfilled demand
        SUM(
            CASE
                WHEN reporting_month = '2026-10-01'
                THEN unfulfilled_units
                ELSE 0
            END
        ) AS october_unfulfilled_units

    FROM monthly_inventory

    GROUP BY
        sku_id,
        warehouse

),

-- =========================================================
-- STEP 3: PORTFOLIO TOTALS AND HISTORICAL RANKINGS
-- =========================================================

location_rankings AS (

    SELECT

        location_history.*,

        -- Most stockout months gets Rank 1
        DENSE_RANK() OVER (

            ORDER BY stockout_months DESC

        ) AS stockout_recurrence_rank,

        -- Highest historical financial exposure
        -- gets Rank 1
        DENSE_RANK() OVER (

            ORDER BY historical_margin_exposure_inr DESC

        ) AS historical_financial_rank,

        -- Total SKU-warehouse combinations
        COUNT(*) OVER ()
            AS portfolio_locations,

        -- Locations with stockouts in 2+ months
        SUM(
            CASE
                WHEN stockout_months >= 2
                THEN 1 ELSE 0
            END
        ) OVER ()
            AS portfolio_recurring_stockout_locations,

        -- Total stockout location-month occurrences
        SUM(stockout_months) OVER ()
            AS portfolio_stockout_location_months,

        -- Historical portfolio unmet demand
        SUM(historical_unfulfilled_units) OVER ()
            AS portfolio_historical_unfulfilled_units,

        -- Historical portfolio potential exposure
        SUM(historical_margin_exposure_inr) OVER ()
            AS portfolio_historical_margin_exposure_inr

    FROM location_history

)

-- =========================================================
-- STEP 4: DISPLAY TOP 15 RECURRING RISK LOCATIONS
-- =========================================================

SELECT

    sku_id,

    product_name,

    category,

    warehouse,

    supplier_id,

    months_observed,

    stockout_months,

    zero_closing_stock_months,

    below_reorder_months,

    healthy_months,

    historical_stockout_days,

    months_with_unfulfilled_demand,

    historical_unfulfilled_units,

    ROUND(
        historical_margin_exposure_inr,
        2
    ) AS historical_margin_exposure_inr,

    recent_3m_stockout_months,

    october_inventory_status,

    october_unfulfilled_units,

    stockout_recurrence_rank,

    historical_financial_rank,

    -- Portfolio-wide reconciliation
    portfolio_locations,

    portfolio_recurring_stockout_locations,

    portfolio_stockout_location_months,

    portfolio_historical_unfulfilled_units,

    ROUND(
        portfolio_historical_margin_exposure_inr,
        2
    ) AS portfolio_historical_margin_exposure_inr

FROM location_rankings

ORDER BY

    stockout_months DESC,

    historical_unfulfilled_units DESC,

    historical_margin_exposure_inr DESC,

    sku_id,

    warehouse

LIMIT 15;
-- =========================================================
-- SECTION 07.4: VERIFIED HISTORICAL SKU-WAREHOUSE RISK
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
-- OUTPUT:
-- Top 15 Recurring SKU-Warehouse Locations
-- 24 Columns
--
-- VALIDATION STATUS:
-- PASSED - Historical benchmarks, location
-- classifications and rankings reconciled.
--
-- =========================================================
-- A. HISTORICAL PORTFOLIO SUMMARY
-- =========================================================
--
-- Historical Source Records          : 4320
-- Unique SKU-Warehouse Locations     : 360
-- Reporting Months                   : 12
--
-- Locations With Repeated Stockouts  : 216
--
-- Repeated Stockout Location Rate:
-- 216 / 360 * 100 = 60.00%
--
-- Total Stockout Location-Months     : 815
--
-- Stockout Location-Month Rate:
-- 815 / 4320 * 100 = 18.87%
--
-- Historical Unfulfilled Units       : 36424
--
-- Historical Potential Margin Exposure:
-- INR 33058084.60
--
-- Reconciliation:
-- Historical unmet demand and potential
-- exposure match Script 04.
--
-- =========================================================
-- B. RECURRING STOCKOUT DEFINITIONS
-- =========================================================
--
-- NO RECORDED STOCKOUT:
-- stockout_months = 0
--
-- ONE-MONTH OCCURRENCE:
-- stockout_months = 1
--
-- REPEATED STOCKOUT OCCURRENCE:
-- stockout_months >= 2
--
-- Stockout Months:
-- SUM(CASE WHEN stockout_days > 0
--          THEN 1 ELSE 0 END)
--
-- Historical Stockout Days:
-- SUM(stockout_days)
--
-- These are distinct measures.
--
-- Recurrence measures historical frequency,
-- not predicted future stockout probability.
--
-- =========================================================
-- C. TOP 15 HISTORICAL STOCKOUT LOCATIONS
-- =========================================================
--
-- SKU      Warehouse  Supplier  Months  Stockout Days
--
-- SKU0060  West       SUP006      8         104
-- SKU0113  North      SUP011      8          76
-- SKU0060  South      SUP006      7         135
-- SKU0003  West       SUP001      7         113
-- SKU0046  North      SUP006      7          80
-- SKU0001  West       SUP001      7          68
-- SKU0037  West       SUP003      7          44
-- SKU0104  West       SUP012      6          92
-- SKU0041  West       SUP005      6          90
-- SKU0032  North      SUP004      6          81
-- SKU0056  South      SUP006      6          71
-- SKU0027  South      SUP003      6          60
-- SKU0039  North      SUP003      6          85
-- SKU0031  West       SUP003      6          50
-- SKU0054  West       SUP006      6          36
--
-- Rank Distribution:
-- 2 locations with 8 stockout months.
-- 5 locations with 7 stockout months.
-- 8 locations with 6 stockout months.
--
-- DENSE_RANK() correctly preserved ties.
--
-- =========================================================
-- D. TOP-15 HISTORICAL CONTRIBUTION
-- =========================================================
--
-- Top-15 Stockout Location-Months:
-- 99
--
-- Portfolio Stockout Location-Months:
-- 815
--
-- Contribution:
-- 99 / 815 * 100 = 12.15%
--
-- Top-15 Historical Stockout Days:
-- 1185 location-days
--
-- Top-15 Historical Unfulfilled Units:
-- 6540
--
-- Historical Portfolio Unfulfilled Units:
-- 36424
--
-- Contribution:
-- 6540 / 36424 * 100 = 17.96%
--
-- Top-15 Potential Margin Exposure:
-- INR 6633377.99
--
-- Historical Portfolio Margin Exposure:
-- INR 33058084.60
--
-- Contribution:
-- 6633377.99 / 33058084.60 * 100
-- = 20.07%
--
-- IMPORTANT:
-- These shares relate to the 15 locations
-- selected by stockout recurrence.
--
-- They are not the financial top-15 ranking.
--
-- =========================================================
-- E. SKU0060: MULTI-WAREHOUSE RECURRENCE
-- =========================================================
--
-- SKU:
-- SKU0060 - Home & Living Product 20
--
-- Supplier:
-- SUP006
--
-- WEST WAREHOUSE:
-- Stockout Months                  : 8
-- Historical Stockout Days         : 104
-- Historical Unfulfilled Units     : 644
-- Historical Margin Exposure       : INR 287687.68
-- October Closing Status           : HEALTHY
--
-- SOUTH WAREHOUSE:
-- Stockout Months                  : 7
-- Historical Stockout Days         : 135
-- Historical Unfulfilled Units     : 882
-- Historical Margin Exposure       : INR 394007.04
-- October Closing Status           : ZERO STOCK
-- October Unfulfilled Units        : 182
--
-- COMBINED WEST + SOUTH:
-- Historical Unfulfilled Units:
-- 644 + 882 = 1526
--
-- Stockout Location-Days:
-- 104 + 135 = 239
--
-- Potential Margin Exposure:
-- INR 681694.72
--
-- INTERPRETATION:
-- The same SKU has repeated shortages
-- in two different warehouses.
--
-- Investigate demand, replenishment and
-- stock availability separately by warehouse.
--
-- =========================================================
-- F. HIGHEST HISTORICAL FINANCIAL EXPOSURE
-- =========================================================
--
-- SKU0104 - WEST:
-- Stockout Months                  : 6
-- Historical Potential Exposure    : INR 1549227.68
-- Historical Financial Rank        : 1
-- October Closing Status           : HEALTHY
--
-- SKU0003 - WEST:
-- Stockout Months                  : 7
-- Historical Potential Exposure    : INR 1492100.37
-- Historical Financial Rank        : 2
-- October Closing Status           : BELOW REORDER
--
-- Combined Historical Exposure:
-- INR 3041328.05
--
-- Portfolio Historical Exposure Share:
-- 3041328.05 / 33058084.60 * 100
-- = 9.20%
--
-- BUSINESS INTERPRETATION:
-- Highest financial exposure and highest
-- stockout recurrence are not necessarily
-- associated with the same locations.
--
-- Both dimensions should be investigated.
--
-- =========================================================
-- G. RECENT THREE-MONTH STOCKOUTS
-- =========================================================
--
-- PERIOD:
-- August, September and October 2026
--
-- Locations With Stockouts In All 3 Months:
--
-- SKU0001  West   SUP001
-- SKU0041  West   SUP005
-- SKU0056  South  SUP006
-- SKU0054  West   SUP006
--
-- October Unfulfilled Units:
--
-- SKU0001 West                   :   1
-- SKU0041 West                   : 250
-- SKU0056 South                  :  37
-- SKU0054 West                   :  50
--
-- All four finished October with zero stock.
--
-- INTERPRETATION:
-- These locations have recent recurring
-- shortage occurrences.
--
-- They did not necessarily remain
-- continuously out of stock for three months.
--
-- =========================================================
-- H. OCTOBER STATUS OF TOP 15
-- =========================================================
--
-- ZERO CLOSING STOCK              : 8
-- POSITIVE BELOW REORDER          : 3
-- HEALTHY CLOSING STOCK           : 4
--
-- Reconciliation:
-- 8 + 3 + 4 = 15
--
-- October Unfulfilled Units
-- Across These 15 Locations:
-- 689
--
-- Share of October Unfulfilled Demand:
-- 689 / 3681 * 100 = 18.72%
--
-- IMPORTANT:
-- Historical recurrence and latest closing
-- status describe different risk dimensions.
--
-- A currently healthy closing balance does not
-- prove that historical stockout causes have
-- been permanently resolved.
--
-- =========================================================
-- I. SQL TECHNIQUES
-- =========================================================
--
-- COUNT(DISTINCT reporting_month):
-- Confirms reporting-month coverage.
--
-- SUM(stockout_flag):
-- Counts months with stockout occurrences.
--
-- SUM(stockout_days):
-- Counts total recorded stockout days.
--
-- SUM(below_reorder_flag):
-- Counts positive-stock below-reorder months.
--
-- MAX(CASE WHEN reporting_month =
--     '2026-10-01' THEN inventory_status END):
-- Retrieves October closing-stock status.
--
-- DENSE_RANK():
-- Ranks historical recurrence and
-- financial exposure independently.
--
-- SUM(...) OVER():
-- Calculates historical portfolio totals
-- before displaying the top 15 locations.
--
-- =========================================================
-- J. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- RECURRENCE INVESTIGATION:
-- SKU0060 West and SKU0113 North
-- each recorded stockouts in 8 months.
--
-- MULTI-WAREHOUSE INVESTIGATION:
-- SKU0060 West and South.
--
-- RECENT PERSISTENT OCCURRENCES:
-- SKU0001 West
-- SKU0041 West
-- SKU0056 South
-- SKU0054 West
--
-- HISTORICAL FINANCIAL EXPOSURE:
-- SKU0104 West and SKU0003 West.
--
-- These represent different investigation
-- priorities rather than a composite ranking.
--
-- =========================================================
-- K. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business data.
--
-- 2. Repeated stockouts are identified using
--    monthly records, not event-level logs.
--
-- 3. Historical recurrence does not prove
--    the causes of shortages.
--
-- 4. Historical financial exposure is
--    not confirmed lost profit.
--
-- 5. October healthy closing stock does not
--    establish that future risk is eliminated.
--
-- 6. Monthly stockout duration and stockout
--    frequency are separate measurements.
--
-- 7. Supplier attribution does not prove
--    supplier-caused shortages.
--
-- 8. Independent CSV-level reconciliation
--    remains scheduled for Script 09.
--
-- =========================================================
-- SECTION 07.4 STATUS:
-- VERIFIED
--
-- NEXT:
-- SECTION 07.5 - FINAL INVENTORY RISK QA
-- =========================================================
-- =========================================================
-- SECTION 07.5: FINAL INVENTORY RISK RECONCILIATION & QA
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
--
-- PERIOD: November 2025 through October 2026
-- DATABASE: supply_chain_ai_db
--
-- PURPOSE:
-- Validate the complete inventory-risk investigation.
--
-- SECTIONS COVERED:
-- 07.1 Inventory Classification
-- 07.2 Financial Shortage Rankings
-- 07.3 Reorder-Point Gap Rankings
-- 07.4 Historical Recurring Inventory Risk
--
-- OUTPUT:
-- One vertical metric | value result table.
--
-- IMPORTANT:
-- Do not mark this script complete until all
-- validations pass.
-- =========================================================


WITH base_rows AS (

    SELECT
        reporting_month,
        sku_id,
        warehouse,
        supplier_id,

        closing_stock_units,
        reorder_point_units,
        stockout_days,
        demand_units,
        fulfilled_units,
        supplier_deliveries_count,
        replenishment_lead_time_days,
        unit_cost,
        unit_selling_price,

        CASE
            WHEN closing_stock_units = 0
                THEN 'ZERO CLOSING STOCK'

            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
                THEN 'POSITIVE BELOW REORDER'

            WHEN closing_stock_units >= reorder_point_units
                THEN 'HEALTHY CLOSING STOCK'

            ELSE 'INVALID'
        END AS stock_status,

        CASE
            WHEN stockout_days > 0 THEN 1
            ELSE 0
        END AS stockout_flag,

        CASE
            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
            THEN reorder_point_units - closing_stock_units
            ELSE 0
        END AS reorder_gap_units,

        demand_units - fulfilled_units
            AS unfulfilled_units,

        (demand_units - fulfilled_units)
        * GREATEST(unit_selling_price - unit_cost, 0)
            AS margin_exposure_inr

    FROM supply_chain_ai_db.inventory
),

-- =========================================================
-- A. HISTORICAL SOURCE STRUCTURE
-- =========================================================

historical_summary AS (

    SELECT
        COUNT(*) AS source_records,

        COUNT(DISTINCT reporting_month)
            AS reporting_months,

        MIN(reporting_month) AS first_month,
        MAX(reporting_month) AS last_month,

        COUNT(DISTINCT sku_id) AS distinct_skus,
        COUNT(DISTINCT warehouse) AS distinct_warehouses,

        COUNT(DISTINCT reporting_month, sku_id, warehouse)
            AS unique_grain_records,

        SUM(
            CASE
                WHEN reporting_month IS NULL
                  OR reporting_month < '2025-11-01'
                  OR reporting_month > '2026-10-01'
                  OR DAY(reporting_month) <> 1
                THEN 1 ELSE 0
            END
        ) AS invalid_month_records,

        SUM(
            CASE
                WHEN reporting_month IS NULL
                  OR sku_id IS NULL
                  OR warehouse IS NULL
                  OR closing_stock_units IS NULL
                  OR reorder_point_units IS NULL
                  OR stockout_days IS NULL
                  OR demand_units IS NULL
                  OR fulfilled_units IS NULL
                  OR unit_cost IS NULL
                  OR unit_selling_price IS NULL
                  OR closing_stock_units < 0
                  OR reorder_point_units < 0
                  OR stockout_days < 0
                  OR demand_units < 0
                  OR fulfilled_units < 0
                  OR fulfilled_units > demand_units
                THEN 1 ELSE 0
            END
        ) AS invalid_inventory_records,

        SUM(
            CASE
                WHEN stock_status <> 'INVALID'
                THEN 1 ELSE 0
            END
        ) AS classified_historical_records,

        SUM(stockout_flag)
            AS historical_stockout_location_months,

        SUM(unfulfilled_units)
            AS historical_unfulfilled_units,

        SUM(margin_exposure_inr)
            AS historical_margin_exposure

    FROM base_rows
),

-- =========================================================
-- B. TWELVE-MONTH SKU-WAREHOUSE HISTORY
-- =========================================================

location_history AS (

    SELECT
        sku_id,
        warehouse,

        COUNT(*) AS observed_rows,

        COUNT(DISTINCT reporting_month)
            AS months_observed,

        SUM(stockout_flag) AS stockout_months,

        SUM(stockout_days)
            AS historical_stockout_days,

        SUM(unfulfilled_units)
            AS location_unfulfilled_units,

        SUM(margin_exposure_inr)
            AS location_margin_exposure,

        SUM(
            CASE WHEN stock_status = 'ZERO CLOSING STOCK'
                 THEN 1 ELSE 0 END
        ) AS zero_months,

        SUM(
            CASE WHEN stock_status = 'POSITIVE BELOW REORDER'
                 THEN 1 ELSE 0 END
        ) AS below_reorder_months,

        SUM(
            CASE WHEN stock_status = 'HEALTHY CLOSING STOCK'
                 THEN 1 ELSE 0 END
        ) AS healthy_months,

        SUM(
            CASE WHEN reporting_month = '2026-10-01'
                 THEN 1 ELSE 0 END
        ) AS october_rows,

        MAX(
            CASE WHEN reporting_month = '2026-10-01'
                 THEN stock_status ELSE NULL END
        ) AS october_status,

        SUM(
            CASE WHEN reporting_month = '2026-10-01'
                 THEN unfulfilled_units ELSE 0 END
        ) AS october_unfulfilled_units

    FROM base_rows

    GROUP BY sku_id, warehouse
),

location_summary AS (

    SELECT
        COUNT(*) AS location_count,

        SUM(
            CASE
                WHEN observed_rows <> 12
                  OR months_observed <> 12
                THEN 1 ELSE 0
            END
        ) AS incomplete_locations,

        SUM(
            CASE
                WHEN zero_months
                   + below_reorder_months
                   + healthy_months <> observed_rows
                THEN 1 ELSE 0
            END
        ) AS category_mismatch_locations,

        SUM(
            CASE WHEN october_rows <> 1
                 THEN 1 ELSE 0 END
        ) AS incorrect_october_groups,

        SUM(
            CASE WHEN stockout_months >= 2
                 THEN 1 ELSE 0 END
        ) AS recurring_locations

    FROM location_history
),

-- =========================================================
-- C. OCTOBER INVENTORY CLASSIFICATION
-- =========================================================

october_rows AS (

    SELECT *

    FROM base_rows

    WHERE reporting_month = '2026-10-01'
),

october_summary AS (

    SELECT
        COUNT(*) AS october_locations,

        SUM(
            CASE WHEN stock_status = 'ZERO CLOSING STOCK'
                 THEN 1 ELSE 0 END
        ) AS october_zero,

        SUM(
            CASE WHEN stock_status = 'POSITIVE BELOW REORDER'
                 THEN 1 ELSE 0 END
        ) AS october_below_reorder,

        SUM(
            CASE WHEN stock_status = 'HEALTHY CLOSING STOCK'
                 THEN 1 ELSE 0 END
        ) AS october_healthy,

        SUM(stockout_flag)
            AS october_stockout_locations,

        SUM(
            CASE
                WHEN (
                    stockout_flag = 1
                    AND stock_status <> 'ZERO CLOSING STOCK'
                )
                OR (
                    stockout_flag = 0
                    AND stock_status = 'ZERO CLOSING STOCK'
                )
                THEN 1 ELSE 0
            END
        ) AS stockout_zero_disagreements,

        SUM(stockout_days)
            AS october_stockout_days,

        SUM(
            CASE WHEN unfulfilled_units > 0
                 THEN 1 ELSE 0 END
        ) AS october_unfulfilled_locations,

        SUM(unfulfilled_units)
            AS october_unfulfilled_units,

        SUM(reorder_gap_units)
            AS october_reorder_gap,

        SUM(margin_exposure_inr)
            AS october_margin_exposure

    FROM october_rows
),

-- =========================================================
-- D. REBUILD TOP-15 FINANCIAL RANKINGS
-- =========================================================

financial_ranked AS (

    SELECT
        october_rows.*,

        ROW_NUMBER() OVER (
            ORDER BY
                margin_exposure_inr DESC,
                sku_id,
                warehouse
        ) AS financial_row_number

    FROM october_rows

    WHERE stockout_flag = 1
       OR unfulfilled_units > 0
),

financial_summary AS (

    SELECT
        COUNT(*) AS shortage_candidate_locations,

        SUM(
            CASE WHEN financial_row_number <= 15
                 THEN 1 ELSE 0 END
        ) AS financial_top15_rows,

        SUM(
            CASE WHEN financial_row_number <= 15
                 THEN margin_exposure_inr ELSE 0 END
        ) AS financial_top15_exposure,

        SUM(
            CASE WHEN financial_row_number <= 15
                 THEN unfulfilled_units ELSE 0 END
        ) AS financial_top15_unfulfilled,

        SUM(
            CASE WHEN financial_row_number <= 15
                 THEN stockout_days ELSE 0 END
        ) AS financial_top15_stockout_days

    FROM financial_ranked
),

-- =========================================================
-- E. REBUILD TOP-15 REORDER-GAP RANKINGS
-- =========================================================

reorder_ranked AS (

    SELECT
        october_rows.*,

        ROW_NUMBER() OVER (
            ORDER BY
                reorder_gap_units DESC,
                demand_units DESC,
                sku_id,
                warehouse
        ) AS reorder_row_number,

        closing_stock_units
        * DAY(LAST_DAY(reporting_month)) * 1.0
        / NULLIF(demand_units, 0)
            AS indicative_cover_days,

        CASE
            WHEN supplier_deliveries_count > 0
             AND replenishment_lead_time_days IS NOT NULL
            THEN replenishment_lead_time_days
            ELSE NULL
        END AS observed_lead_days

    FROM october_rows

    WHERE stock_status = 'POSITIVE BELOW REORDER'
),

reorder_summary AS (

    SELECT
        COUNT(*) AS reorder_candidate_locations,

        SUM(
            CASE WHEN reorder_row_number <= 15
                 THEN 1 ELSE 0 END
        ) AS reorder_top15_rows,

        SUM(
            CASE WHEN reorder_row_number <= 15
                 THEN reorder_gap_units ELSE 0 END
        ) AS reorder_top15_gap,

        SUM(
            CASE
                WHEN reorder_row_number <= 15
                 AND indicative_cover_days < observed_lead_days
                THEN 1 ELSE 0
            END
        ) AS reorder_top15_cover_below_lead

    FROM reorder_ranked
),

-- =========================================================
-- F. REBUILD TOP-15 RECURRENCE RANKINGS
-- =========================================================

recurrence_ranked AS (

    SELECT
        location_history.*,

        ROW_NUMBER() OVER (
            ORDER BY
                stockout_months DESC,
                location_unfulfilled_units DESC,
                location_margin_exposure DESC,
                sku_id,
                warehouse
        ) AS recurrence_row_number

    FROM location_history
),

recurrence_summary AS (

    SELECT
        SUM(
            CASE WHEN recurrence_row_number <= 15
                 THEN 1 ELSE 0 END
        ) AS recurrence_top15_rows,

        SUM(
            CASE WHEN recurrence_row_number <= 15
                 THEN stockout_months ELSE 0 END
        ) AS recurrence_top15_months,

        SUM(
            CASE WHEN recurrence_row_number <= 15
                 THEN historical_stockout_days ELSE 0 END
        ) AS recurrence_top15_stockout_days,

        SUM(
            CASE WHEN recurrence_row_number <= 15
                 THEN location_unfulfilled_units ELSE 0 END
        ) AS recurrence_top15_unfulfilled,

        SUM(
            CASE WHEN recurrence_row_number <= 15
                 THEN location_margin_exposure ELSE 0 END
        ) AS recurrence_top15_exposure,

        SUM(
            CASE
                WHEN recurrence_row_number <= 15
                 AND october_status = 'ZERO CLOSING STOCK'
                THEN 1 ELSE 0
            END
        ) AS recurrence_top15_zero,

        SUM(
            CASE
                WHEN recurrence_row_number <= 15
                 AND october_status = 'POSITIVE BELOW REORDER'
                THEN 1 ELSE 0
            END
        ) AS recurrence_top15_below,

        SUM(
            CASE
                WHEN recurrence_row_number <= 15
                 AND october_status = 'HEALTHY CLOSING STOCK'
                THEN 1 ELSE 0
            END
        ) AS recurrence_top15_healthy,

        SUM(
            CASE WHEN recurrence_row_number <= 15
                 THEN october_unfulfilled_units ELSE 0 END
        ) AS recurrence_top15_october_unfulfilled

    FROM recurrence_ranked
),

-- =========================================================
-- G. COLLECT AUDIT MEASURES
-- =========================================================

all_metrics AS (

    SELECT
        h.*,
        l.*,
        o.*,
        f.*,
        r.*,
        t.*

    FROM historical_summary h
    CROSS JOIN location_summary l
    CROSS JOIN october_summary o
    CROSS JOIN financial_summary f
    CROSS JOIN reorder_summary r
    CROSS JOIN recurrence_summary t
),

-- =========================================================
-- H. EXPLICIT QA RULES
-- 0 = PASS, 1 = FAIL
-- =========================================================

validation_rules AS (

    SELECT 1 AS id, 'Source row count' AS rule_name,
        IF(source_records = 4320, 0, 1) AS failed
    FROM all_metrics

    UNION ALL SELECT 2, 'Historical month coverage',
        IF(reporting_months = 12
           AND first_month = '2025-11-01'
           AND last_month = '2026-10-01', 0, 1)
    FROM all_metrics

    UNION ALL SELECT 3, 'Valid reporting-month dates',
        IF(invalid_month_records = 0, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 4, 'Distinct SKU count',
        IF(distinct_skus = 120, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 5, 'Distinct warehouse count',
        IF(distinct_warehouses = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 6, 'Unique inventory grain',
        IF(unique_grain_records = source_records, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 7, 'Valid inventory observations',
        IF(invalid_inventory_records = 0, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 8, '360 SKU-warehouse locations',
        IF(location_count = 360, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 9, 'Complete 12-month location histories',
        IF(incomplete_locations = 0, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 10, 'October record per location',
        IF(incorrect_october_groups = 0, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 11, 'Location status-month reconciliation',
        IF(category_mismatch_locations = 0, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 12, 'Historical status classification',
        IF(classified_historical_records = 4320, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 13, 'Historical stockout location-months',
        IF(historical_stockout_location_months = 815, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 14, 'Recurring-stockout locations',
        IF(recurring_locations = 216, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 15, 'Historical unfulfilled units',
        IF(historical_unfulfilled_units = 36424, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 16, 'Historical margin exposure',
        IF(ABS(historical_margin_exposure
               - 33058084.60) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 17, 'October location count',
        IF(october_locations = 360, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 18, 'October zero-stock locations',
        IF(october_zero = 79, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 19, 'October below-reorder locations',
        IF(october_below_reorder = 141, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 20, 'October healthy locations',
        IF(october_healthy = 140, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 21, 'October classification balance',
        IF(october_zero
           + october_below_reorder
           + october_healthy = october_locations, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 22, 'October stockout occurrences',
        IF(october_stockout_locations = 79, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 23, 'October stockout-zero overlap',
        IF(stockout_zero_disagreements = 0, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 24, 'October stockout days',
        IF(october_stockout_days = 751, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 25, 'October unmet-demand locations',
        IF(october_unfulfilled_locations = 79, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 26, 'October unfulfilled units',
        IF(october_unfulfilled_units = 3681, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 27, 'October margin exposure',
        IF(ABS(october_margin_exposure
               - 3071205.83) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 28, 'October positive-stock reorder gap',
        IF(october_reorder_gap = 4544, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 29, 'Financial shortage population',
        IF(shortage_candidate_locations = 79, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 30, 'Financial top-15 row count',
        IF(financial_top15_rows = 15, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 31, 'Financial top-15 exposure',
        IF(ABS(financial_top15_exposure
               - 1946479.99) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 32, 'Financial top-15 unfulfilled units',
        IF(financial_top15_unfulfilled = 1779, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 33, 'Financial top-15 stockout days',
        IF(financial_top15_stockout_days = 316, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 34, 'Reorder-risk population',
        IF(reorder_candidate_locations = 141, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 35, 'Reorder top-15 row count',
        IF(reorder_top15_rows = 15, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 36, 'Reorder top-15 gap units',
        IF(reorder_top15_gap = 1309, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 37, 'Top-15 coverage below lead time',
        IF(reorder_top15_cover_below_lead = 15, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 38, 'Recurrence top-15 row count',
        IF(recurrence_top15_rows = 15, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 39, 'Recurrence top-15 stockout months',
        IF(recurrence_top15_months = 99, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 40, 'Recurrence top-15 unfulfilled units',
        IF(recurrence_top15_unfulfilled = 6540, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 41, 'Recurrence top-15 margin exposure',
        IF(ABS(recurrence_top15_exposure
               - 6633377.99) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 42, 'Recurrence top-15 stockout days',
        IF(recurrence_top15_stockout_days = 1185, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 43, 'Recurrence top-15 October statuses',
        IF(recurrence_top15_zero = 8
           AND recurrence_top15_below = 3
           AND recurrence_top15_healthy = 4, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 44, 'Recurrence top-15 October unmet units',
        IF(recurrence_top15_october_unfulfilled = 689, 0, 1)
    FROM all_metrics
),

-- =========================================================
-- I. OVERALL PASS/FAIL RESULT
-- =========================================================

qa_summary AS (

    SELECT
        COUNT(*) AS checks_executed,

        SUM(failed) AS failed_checks,

        COALESCE(
            GROUP_CONCAT(
                CASE
                    WHEN failed = 1 THEN rule_name
                    ELSE NULL
                END
                ORDER BY id SEPARATOR '; '
            ),
            'None'
        ) AS failed_rule_names

    FROM validation_rules
),

-- =========================================================
-- J. VERTICAL METRIC | VALUE OUTPUT
-- =========================================================

report_rows AS (

    SELECT 1 AS seq,
        'Source Inventory Records' AS metric,
        CAST(source_records AS CHAR) AS value
    FROM all_metrics

    UNION ALL SELECT 2, 'Historical Reporting Months',
        CAST(reporting_months AS CHAR) FROM all_metrics

    UNION ALL SELECT 3, 'First Reporting Month',
        CAST(first_month AS CHAR) FROM all_metrics

    UNION ALL SELECT 4, 'Last Reporting Month',
        CAST(last_month AS CHAR) FROM all_metrics

    UNION ALL SELECT 5, 'Distinct SKUs',
        CAST(distinct_skus AS CHAR) FROM all_metrics

    UNION ALL SELECT 6, 'Distinct Warehouses',
        CAST(distinct_warehouses AS CHAR) FROM all_metrics

    UNION ALL SELECT 7, 'Unique Inventory Grain Records',
        CAST(unique_grain_records AS CHAR) FROM all_metrics

    UNION ALL SELECT 8, 'Invalid Reporting Month Records',
        CAST(invalid_month_records AS CHAR) FROM all_metrics

    UNION ALL SELECT 9, 'Invalid Inventory Records',
        CAST(invalid_inventory_records AS CHAR) FROM all_metrics

    UNION ALL SELECT 10, 'SKU-Warehouse Locations',
        CAST(location_count AS CHAR) FROM all_metrics

    UNION ALL SELECT 11, 'Incomplete Location Histories',
        CAST(incomplete_locations AS CHAR) FROM all_metrics

    UNION ALL SELECT 12, 'Location Status Mismatches',
        CAST(category_mismatch_locations AS CHAR) FROM all_metrics

    UNION ALL SELECT 13, 'Incorrect October Location Groups',
        CAST(incorrect_october_groups AS CHAR) FROM all_metrics

    UNION ALL SELECT 14, 'Historical Stockout Location-Months',
        CAST(historical_stockout_location_months AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 15, 'Recurring Stockout Locations',
        CAST(recurring_locations AS CHAR) FROM all_metrics

    UNION ALL SELECT 16, 'Historical Unfulfilled Units',
        CAST(historical_unfulfilled_units AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 17, 'Historical Potential Margin (INR)',
        CAST(ROUND(historical_margin_exposure,2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 18, 'October Inventory Locations',
        CAST(october_locations AS CHAR) FROM all_metrics

    UNION ALL SELECT 19, 'October Zero-Stock Locations',
        CAST(october_zero AS CHAR) FROM all_metrics

    UNION ALL SELECT 20, 'October Below-Reorder Locations',
        CAST(october_below_reorder AS CHAR) FROM all_metrics

    UNION ALL SELECT 21, 'October Healthy Locations',
        CAST(october_healthy AS CHAR) FROM all_metrics

    UNION ALL SELECT 22, 'October Stockout Locations',
        CAST(october_stockout_locations AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 23, 'Stockout-Zero Classification Mismatches',
        CAST(stockout_zero_disagreements AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 24, 'October Stockout Days',
        CAST(october_stockout_days AS CHAR) FROM all_metrics

    UNION ALL SELECT 25, 'October Unmet-Demand Locations',
        CAST(october_unfulfilled_locations AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 26, 'October Unfulfilled Units',
        CAST(october_unfulfilled_units AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 27, 'October Reorder Gap Units',
        CAST(october_reorder_gap AS CHAR) FROM all_metrics

    UNION ALL SELECT 28, 'October Potential Margin (INR)',
        CAST(ROUND(october_margin_exposure,2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 29, 'Financial Shortage Population',
        CAST(shortage_candidate_locations AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 30, 'Financial Top-15 Exposure (INR)',
        CAST(ROUND(financial_top15_exposure,2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 31, 'Financial Top-15 Unfulfilled Units',
        CAST(financial_top15_unfulfilled AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 32, 'Financial Top-15 Stockout Days',
        CAST(financial_top15_stockout_days AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 33, 'Below-Reorder Population',
        CAST(reorder_candidate_locations AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 34, 'Reorder Top-15 Gap Units',
        CAST(reorder_top15_gap AS CHAR) FROM all_metrics

    UNION ALL SELECT 35, 'Top-15 Coverage Below Lead',
        CAST(reorder_top15_cover_below_lead AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 36, 'Recurrence Top-15 Stockout Months',
        CAST(recurrence_top15_months AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 37, 'Recurrence Top-15 Stockout Days',
        CAST(recurrence_top15_stockout_days AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 38, 'Recurrence Top-15 Unfulfilled Units',
        CAST(recurrence_top15_unfulfilled AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 39, 'Recurrence Top-15 Margin (INR)',
        CAST(ROUND(recurrence_top15_exposure,2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 40, 'Recurrence Top-15 October Zero',
        CAST(recurrence_top15_zero AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 41, 'Recurrence Top-15 October Below Reorder',
        CAST(recurrence_top15_below AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 42, 'Recurrence Top-15 October Healthy',
        CAST(recurrence_top15_healthy AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 43, 'Recurrence Top-15 October Unfulfilled',
        CAST(recurrence_top15_october_unfulfilled AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 44, 'QA Rules Executed',
        CAST(checks_executed AS CHAR) FROM qa_summary

    UNION ALL SELECT 45, 'Failed QA Rules',
        CAST(failed_checks AS CHAR) FROM qa_summary

    UNION ALL SELECT 46, 'Failed Rule Names',
        failed_rule_names FROM qa_summary

    UNION ALL SELECT 47, 'Overall Inventory Risk QA Status',
        CASE
            WHEN checks_executed = 44
             AND failed_checks = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM qa_summary
)

-- =========================================================
-- FINAL OUTPUT
-- =========================================================

SELECT
    metric,
    value

FROM report_rows

ORDER BY seq;
-- =========================================================
-- SECTION 07.5: FINAL INVENTORY RISK
--               RECONCILIATION & QUALITY ASSURANCE
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- VALIDATION STATUS:
-- VERIFIED - PASS
--
-- QA Report Rows Returned       : 47
-- QA Validation Rules Executed  : 44
-- Passed Rules                  : 44
-- Failed Rules                  : 0
-- Failed Rule Names             : None
--
-- OVERALL INVENTORY RISK QA STATUS: PASS
--
-- =========================================================
-- A. HISTORICAL DATA STRUCTURE
-- =========================================================
--
-- Source Inventory Records      : 4320
-- Reporting Months              : 12
--
-- First Reporting Month         : 2025-11-01
-- Last Reporting Month          : 2026-10-01
--
-- Distinct SKUs                 : 120
-- Distinct Warehouses           : 3
--
-- Unique Inventory Grain Records:
-- 4320
--
-- SKU-Warehouse Locations       : 360
--
-- Expected Structure:
-- 120 SKUs x 3 Warehouses = 360 Locations
--
-- 360 Locations x 12 Months = 4320 Records
--
-- =========================================================
-- B. SOURCE INTEGRITY
-- =========================================================
--
-- Invalid Reporting Month Records   : 0
-- Invalid Inventory Records         : 0
-- Duplicate Inventory Grain Records : 0
--
-- Incomplete Location Histories     : 0
-- Location Status Mismatches        : 0
-- Incorrect October Location Groups : 0
--
-- All corresponding integrity checks passed.
--
-- =========================================================
-- C. TWELVE-MONTH INVENTORY RISK
-- =========================================================
--
-- Historical Stockout Location-Months:
-- 815
--
-- Recurring Stockout Locations:
-- 216
--
-- Total SKU-Warehouse Locations:
-- 360
--
-- Recurring Stockout Location Rate:
-- 216 / 360 * 100 = 60.00%
--
-- Historical Stockout Location-Month Rate:
-- 815 / 4320 * 100 = 18.87%
--
-- Historical Unfulfilled Units:
-- 36424
--
-- Historical Potential Gross-Margin Exposure:
-- INR 33058084.60
--
-- HISTORICAL RECONCILIATION: PASSED
--
-- =========================================================
-- D. OCTOBER INVENTORY CLASSIFICATION
-- =========================================================
--
-- October SKU-Warehouse Locations:
-- 360
--
-- ZERO CLOSING STOCK:
-- 79 locations
--
-- POSITIVE STOCK BELOW REORDER:
-- 141 locations
--
-- HEALTHY CLOSING STOCK:
-- 140 locations
--
-- Location Classification Reconciliation:
-- 79 + 141 + 140 = 360
--
-- Stockout-Zero Classification Mismatches:
-- 0
--
-- IMPORTANT:
-- Exact overlap between stockouts and
-- zero-closing-stock locations was observed
-- in this synthetic October dataset.
--
-- This is not a universal inventory rule.
--
-- OCTOBER CLASSIFICATION: PASSED
--
-- =========================================================
-- E. OCTOBER SHORTAGE RECONCILIATION
-- =========================================================
--
-- October Stockout Locations:
-- 79
--
-- October Recorded Stockout Days:
-- 751
--
-- October Locations With Unmet Demand:
-- 79
--
-- October Unfulfilled Units:
-- 3681
--
-- October Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- OCTOBER SHORTAGE RECONCILIATION: PASSED
--
-- =========================================================
-- F. SECTION 07.2 FINANCIAL RANKING QA
-- =========================================================
--
-- Total Shortage Locations:
-- 79
--
-- Financial Top-15 Locations:
-- 15
--
-- Top-15 Unfulfilled Units:
-- 1779
--
-- Share of Portfolio Unfulfilled Units:
-- 1779 / 3681 * 100 = 48.33%
--
-- Top-15 Stockout Days:
-- 316
--
-- Share of Portfolio Stockout Days:
-- 316 / 751 * 100 = 42.08%
--
-- Top-15 Potential Margin Exposure:
-- INR 1946479.99
--
-- Share of October Portfolio Exposure:
-- 1946479.99 / 3071205.83 * 100
-- = 63.38%
--
-- FINANCIAL RANKING RECONCILIATION: PASSED
--
-- BUSINESS FINDING:
-- Fifteen shortage locations account for
-- 63.38% of October potential financial exposure.
--
-- The ranking identifies investigation
-- priorities, not guaranteed recoverable profit.
--
-- =========================================================
-- G. SECTION 07.3 REORDER GAP QA
-- =========================================================
--
-- Positive-Stock Below-Reorder Locations:
-- 141
--
-- Portfolio Positive-Stock Reorder Gap:
-- 4544 units
--
-- Top-15 Reorder Locations:
-- 15
--
-- Top-15 Gap Units:
-- 1309
--
-- Top-15 Gap Contribution:
-- 1309 / 4544 * 100 = 28.81%
--
-- Top-15 Locations With Indicative Coverage
-- Below Observed Lead Time:
-- 15
--
-- REORDER GAP RECONCILIATION: PASSED
--
-- IMPORTANT:
-- A reorder gap is not automatically
-- a recommended purchase-order quantity.
--
-- Indicative stock coverage is based on
-- average historical demand.
--
-- Observed lead time is not a guaranteed
-- future replenishment lead time.
--
-- =========================================================
-- H. SECTION 07.4 RECURRING RISK QA
-- =========================================================
--
-- Recurring Stockout Locations:
-- 216
--
-- Portfolio Stockout Location-Months:
-- 815
--
-- Top-15 Recurring Locations:
-- 15
--
-- Top-15 Stockout Location-Months:
-- 99
--
-- Top-15 Stockout Days:
-- 1185
--
-- Top-15 Historical Unfulfilled Units:
-- 6540
--
-- Top-15 Historical Potential Margin Exposure:
-- INR 6633377.99
--
-- Share of Historical Exposure:
-- 6633377.99 / 33058084.60 * 100
-- = 20.07%
--
-- OCTOBER STATUS OF TOP-15 RECURRING LOCATIONS:
--
-- Zero Closing Stock             : 8
-- Positive Below Reorder         : 3
-- Healthy Closing Stock          : 4
--
-- Classification Check:
-- 8 + 3 + 4 = 15
--
-- October Unfulfilled Units Among These Locations:
-- 689
--
-- RECURRING INVENTORY RISK QA: PASSED
--
-- =========================================================
-- I. QA VALIDATION RESULTS
-- =========================================================
--
-- 01. Source row count                   PASS
-- 02. Historical month coverage          PASS
-- 03. Valid reporting-month dates        PASS
-- 04. Distinct SKU count                 PASS
-- 05. Distinct warehouse count           PASS
-- 06. Unique inventory grain             PASS
-- 07. Valid inventory observations       PASS
-- 08. 360 SKU-warehouse locations        PASS
-- 09. Complete location histories        PASS
-- 10. October record per location        PASS
-- 11. Location status-month balance      PASS
-- 12. Historical status classification   PASS
--
-- 13. Historical stockout months         PASS
-- 14. Recurring-stockout locations       PASS
-- 15. Historical unfulfilled units       PASS
-- 16. Historical margin exposure         PASS
--
-- 17. October location count             PASS
-- 18. October zero-stock locations       PASS
-- 19. October below-reorder locations    PASS
-- 20. October healthy locations          PASS
-- 21. October classification balance     PASS
-- 22. October stockout occurrences       PASS
-- 23. October stockout-zero overlap      PASS
-- 24. October stockout days              PASS
-- 25. October unmet-demand locations     PASS
-- 26. October unfulfilled units          PASS
-- 27. October margin exposure            PASS
-- 28. October reorder gap                PASS
--
-- 29. Financial shortage population      PASS
-- 30. Financial top-15 row count         PASS
-- 31. Financial top-15 exposure          PASS
-- 32. Financial top-15 unmet units       PASS
-- 33. Financial top-15 stockout days     PASS
--
-- 34. Reorder-risk population            PASS
-- 35. Reorder top-15 row count           PASS
-- 36. Reorder top-15 gap units           PASS
-- 37. Top-15 coverage versus lead        PASS
--
-- 38. Recurrence top-15 row count        PASS
-- 39. Recurrence top-15 stockout months  PASS
-- 40. Recurrence top-15 unfulfilled      PASS
-- 41. Recurrence top-15 margin exposure  PASS
-- 42. Recurrence top-15 stockout days    PASS
-- 43. Recurrence top-15 October statuses PASS
-- 44. Recurrence top-15 October unmet    PASS
--
-- =========================================================
-- J. COMPLETED SCRIPT 07 SECTIONS
-- =========================================================
--
-- 07.1 - Inventory Risk Classification
-- VERIFIED
--
-- 07.2 - SKU-Level Financial Risk Rankings
-- VERIFIED
--
-- 07.3 - Reorder-Point Gap Analysis
-- VERIFIED
--
-- 07.4 - Historical Recurring Inventory Risk
-- VERIFIED
--
-- 07.5 - Final Inventory Risk QA
-- VERIFIED - 44/44 PASSED
--
-- =========================================================
-- K. FINAL BUSINESS CONCLUSIONS
-- =========================================================
--
-- 1. October shortages were concentrated
--    in 79 SKU-warehouse locations.
--
-- 2. The top 15 financially exposed locations
--    accounted for 63.38% of estimated
--    October potential gross-margin exposure.
--
-- 3. Another 141 locations had positive stock
--    below their reorder thresholds.
--
-- 4. Their combined reorder gap was 4544 units.
--
-- 5. The top 15 reorder-gap locations accounted
--    for 28.81% of the total threshold gap.
--
-- 6. Across twelve months, 216 locations
--    experienced stockouts in two or more months.
--
-- 7. Historical recurrence, current shortages,
--    reorder gaps and financial exposure are
--    different analytical dimensions.
--
-- 8. Business investigation should distinguish
--    immediate shortages from preventive risks.
--
-- =========================================================
-- L. LIMITATIONS & NEXT VALIDATION
-- =========================================================
--
-- 1. The scenario uses synthetic data.
--
-- 2. Historical recurrence is not a validated
--    future stockout prediction.
--
-- 3. Estimated financial exposure is not
--    confirmed lost profit.
--
-- 4. Reorder gaps are not approved
--    purchase-order quantities.
--
-- 5. Supplier-linked inventory observations
--    do not establish shipment-level causation.
--
-- 6. This audit verifies database values
--    against established project benchmarks.
--
-- 7. Independent cleaned-CSV versus SQL
--    reconciliation remains pending
--    in Script 09.
--
-- =========================================================
-- FINAL SCRIPT 07 STATUS:
-- SQL ANALYSIS AND DATABASE QA COMPLETE
--
-- FINAL QA:
-- 44 RULES PASSED
-- ZERO FAILURES
-- OVERALL STATUS: PASS
--
-- NEXT SCRIPT:
-- 08_financial_exposure.sql
-- =========================================================