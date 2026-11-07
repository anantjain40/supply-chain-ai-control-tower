USE supply_chain_ai_db;

-- ===================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 03: CORE BUSINESS KPIs
-- ===================================================

-- KPI 01: ORDER FILL RATE
-- Business Question:
-- What percentage of October 2026 demand was fulfilled?
--
-- Formula:
-- Fill Rate = Fulfilled Units / Demand Units * 100


WITH monthly_summary AS (

    SELECT
        COUNT(*) AS inventory_locations,
        SUM(demand_units) AS total_demand,
        SUM(fulfilled_units) AS total_fulfilled,
        SUM(unfulfilled_units) AS total_unfulfilled

    FROM inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Inventory Locations' AS metric,
       inventory_locations AS value
FROM monthly_summary

UNION ALL

SELECT 'Total Demand Units', total_demand
FROM monthly_summary

UNION ALL

SELECT 'Fulfilled Units', total_fulfilled
FROM monthly_summary

UNION ALL

SELECT 'Unfulfilled Units', total_unfulfilled
FROM monthly_summary

UNION ALL

SELECT 'Fill Rate (%)',
       ROUND(
           total_fulfilled * 100.0 /
           NULLIF(total_demand, 0), 2
       )
FROM monthly_summary;
-- =========================================================
-- KPI 02: MONTHLY STOCKOUT OCCURRENCE RATE
-- =========================================================
--
-- BUSINESS QUESTION:
-- What percentage of SKU-warehouse locations experienced
-- a stockout during October 2026?
--
-- REPORTING GRAIN:
-- One SKU x One Warehouse x One Reporting Month
--
-- NUMERATOR:
-- Number of records where stockout_days > 0
--
-- DENOMINATOR:
-- Total eligible SKU-warehouse records in the month
--
-- FORMULA:
-- Stockout Rate (%) =
-- (Locations with Stockout / Total Locations) * 100
--
-- IMPORTANT:
-- Stockout during the month and zero closing stock
-- are different inventory conditions.
--
-- BUSINESS USE:
-- Measures the spread of inventory availability problems.
--
-- LIMITATION:
-- Does not measure the proportion of days unavailable
-- or directly establish the reason for stockouts.
-- =========================================================

WITH october_stockouts AS (

    SELECT
        COUNT(*) AS total_locations,

        SUM(
            CASE
                WHEN stockout_days > 0 THEN 1
                ELSE 0
            END
        ) AS stockout_locations,

        SUM(
            CASE
                WHEN stockout_days = 0 THEN 1
                ELSE 0
            END
        ) AS locations_without_stockout,

        SUM(
            CASE
                WHEN closing_stock_units = 0 THEN 1
                ELSE 0
            END
        ) AS zero_closing_stock_locations,

        SUM(stockout_days) AS total_stockout_days

    FROM inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM october_stockouts

UNION ALL

SELECT 'Locations With Stockout',
       stockout_locations
FROM october_stockouts

UNION ALL

SELECT 'Locations Without Stockout',
       locations_without_stockout
FROM october_stockouts

UNION ALL

SELECT 'Zero Closing Stock Locations',
       zero_closing_stock_locations
FROM october_stockouts

UNION ALL

SELECT 'Total Stockout Days',
       total_stockout_days
FROM october_stockouts

UNION ALL

SELECT 'Stockout Rate (%)',
       ROUND(
           stockout_locations * 100.0 /
           NULLIF(total_locations, 0), 2
       )
FROM october_stockouts;
-- =========================================================
-- KPI 02: VERIFIED BUSINESS RESULTS
-- Reporting Period: October 2026
-- Source: Cleaned Synthetic Inventory Data
-- =========================================================
--
-- Total SKU-Warehouse Locations : 360
-- Locations With Stockout       : 79
-- Locations Without Stockout    : 281
-- Zero Closing Stock Locations  : 79
-- Total Stockout Days           : 751
-- Stockout Rate                 : 21.94%
--
-- MATHEMATICAL VALIDATION:
-- 79 / 360 * 100 = 21.9444% = 21.94%
-- 79 + 281 = 360 locations
--
-- BUSINESS INTERPRETATION:
-- 21.94% of SKU-warehouse locations experienced
-- at least one stockout in October 2026.
--
-- MANAGEMENT IMPLICATION:
-- Investigate affected products, warehouses,
-- supplier reliability and replenishment patterns.
--
-- LIMITATIONS:
-- 1. Measures stockout occurrence, not lost sales.
-- 2. Does not identify the root cause of stockouts.
-- 3. Total stockout days are summed across locations.
-- 4. Equal stockout and zero-stock counts do not
--    establish that the affected locations are identical.
--
-- STATUS: VALIDATED AGAINST MYSQL OUTPUT
-- =========================================================
-- =========================================================
-- KPI 03: AT-RISK INVENTORY LOCATIONS
-- =========================================================
--
-- BUSINESS QUESTION:
-- How many SKU-warehouse locations have positive inventory
-- but are below their reorder point?
--
-- REPORTING PERIOD: October 2026
-- GRAIN: One SKU x One Warehouse
--
-- AT-RISK CONDITION:
-- closing_stock_units > 0
-- AND closing_stock_units < reorder_point_units
--
-- ZERO STOCK:
-- closing_stock_units = 0
--
-- HEALTHY BY REORDER THRESHOLD:
-- closing_stock_units > 0
-- AND closing_stock_units >= reorder_point_units
--
-- FORMULA:
-- At-Risk Rate =
-- At-Risk Locations / Total Locations * 100
--
-- BUSINESS PURPOSE:
-- Identify locations requiring replenishment attention
-- before they run out of inventory.
--
-- LIMITATION:
-- Being below reorder point does not establish when a
-- stockout will occur. Demand and supplier lead time
-- require further investigation.
-- =========================================================

WITH inventory_risk AS (

    SELECT

        COUNT(*) AS total_locations,

        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1 ELSE 0
            END
        ) AS zero_stock_locations,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units >= reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS healthy_locations

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM inventory_risk

UNION ALL

SELECT 'Zero Stock Locations',
       zero_stock_locations
FROM inventory_risk

UNION ALL

SELECT 'At-Risk Inventory Locations',
       at_risk_locations
FROM inventory_risk

UNION ALL

SELECT 'Healthy Inventory Locations',
       healthy_locations
FROM inventory_risk

UNION ALL

SELECT 'At-Risk Rate (%)',
       ROUND(
           at_risk_locations * 100.0 /
           NULLIF(total_locations, 0), 2
       )
FROM inventory_risk

UNION ALL

SELECT 'Classification Check',
       zero_stock_locations
       + at_risk_locations
       + healthy_locations
FROM inventory_risk;
-- =========================================================
-- KPI 03: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- Reporting Period: October 2026
-- Data Source: Cleaned Synthetic Inventory Dataset
-- Reporting Grain: One SKU x One Warehouse
--
-- VERIFIED RESULTS:
-- Total Inventory Locations       : 360
-- Zero Stock Locations            : 79
-- Positive-Stock At-Risk Locations: 141
-- Healthy-by-Threshold Locations  : 140
-- At-Risk Rate (%)                : 39.17
-- Classification Check            : 360
--
-- MATHEMATICAL VALIDATION:
-- At-Risk Rate = 141 / 360 * 100 = 39.17%
-- Healthy Rate = 140 / 360 * 100 = 38.89%
-- Classification = 79 + 141 + 140 = 360
-- Broader Vulnerable Locations = 79 + 141 = 220
-- Broader Vulnerable Rate = 220 / 360 * 100 = 61.11%
--
-- BUSINESS INTERPRETATION:
-- 141 SKU-warehouse locations have remaining stock
-- below their respective reorder thresholds.
--
-- Another 79 locations have zero closing inventory.
--
-- Only 140 locations meet their reorder thresholds.
--
-- MANAGEMENT IMPLICATION:
-- Inventory Planning should prioritize investigation
-- of the 141 at-risk locations using demand, supplier
-- lead times, and replenishment requirements.
--
-- Locations with zero closing inventory require
-- separate investigation and urgent review.
--
-- LIMITATIONS:
-- 1. At-risk inventory is a threshold-based measure.
-- 2. Being below reorder point does not guarantee
--    a future stockout.
-- 3. Healthy-by-threshold does not imply zero risk.
-- 4. No supplier causality is established by this KPI.
-- 5. The measure is a month-end snapshot.
--
-- VALIDATION STATUS:
-- SQL output verified against 360 locations.
-- SQL-Python reconciliation remains pending.
-- =========================================================
-- =========================================================
-- KPI 04: SUPPLIER ON-TIME DELIVERY RATE
-- =========================================================
--
-- BUSINESS QUESTION:
-- What percentage of supplier delivery lines arrived
-- on time during October 2026?
--
-- REPORTING PERIOD:
-- October 2026
--
-- NUMERATOR:
-- Sum of known on-time supplier delivery lines.
--
-- DENOMINATOR:
-- Sum of supplier delivery lines for records
-- where the on-time delivery count is known.
--
-- FORMULA:
-- Supplier OTD (%) =
-- Known On-Time Delivery Lines
-- / Eligible Delivery Lines * 100
--
-- NULL HANDLING:
-- Records with unknown on-time outcomes are excluded
-- from both numerator and denominator.
--
-- Delivery lines excluded because of unknown outcomes
-- are separately reported for transparency.
--
-- BUSINESS USE:
-- Evaluate supplier reliability and potential
-- replenishment risks.
--
-- LIMITATIONS:
-- 1. Delivery lines are not necessarily distinct orders.
-- 2. Unknown delivery outcomes are excluded.
-- 3. On-time delivery does not measure lead-time duration.
-- 4. Poor supplier reliability alone does not prove
--    the cause of a specific stockout.
-- =========================================================

WITH delivery_quality AS (

    SELECT

        SUM(supplier_deliveries_count)
            AS total_delivery_lines,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_delivery_lines,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_delivery_lines,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NULL
                 AND supplier_deliveries_count > 0
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS excluded_delivery_lines,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count
                     IS NULL
                 AND supplier_deliveries_count > 0
                THEN 1
                ELSE 0
            END
        ) AS unknown_outcome_records

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Recorded Delivery Lines' AS metric,
       total_delivery_lines AS value
FROM delivery_quality

UNION ALL

SELECT 'Eligible Delivery Lines',
       eligible_delivery_lines
FROM delivery_quality

UNION ALL

SELECT 'Confirmed On-Time Delivery Lines',
       on_time_delivery_lines
FROM delivery_quality

UNION ALL

SELECT 'Confirmed Late Delivery Lines',
       eligible_delivery_lines - on_time_delivery_lines
FROM delivery_quality

UNION ALL

SELECT 'Excluded Delivery Lines (Unknown Outcome)',
       excluded_delivery_lines
FROM delivery_quality

UNION ALL

SELECT 'Records With Unknown Delivery Outcome',
       unknown_outcome_records
FROM delivery_quality

UNION ALL

SELECT 'Supplier On-Time Delivery Rate (%)',
       ROUND(
           on_time_delivery_lines * 100.0 /
           NULLIF(eligible_delivery_lines, 0), 2
       )
FROM delivery_quality

UNION ALL

SELECT 'Delivery Line Reconciliation',
       eligible_delivery_lines + excluded_delivery_lines
FROM delivery_quality;
-- =========================================================
-- KPI 04: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- Reporting Period: October 2026
-- Data Source: Cleaned Synthetic Inventory Dataset
-- Measurement Unit: Supplier Delivery Lines
--
-- VERIFIED RESULTS:
-- Total Recorded Delivery Lines  : 730
-- Eligible Delivery Lines        : 729
-- Confirmed On-Time Lines        : 646
-- Confirmed Late Lines           : 83
-- Excluded Unknown Lines         : 1
-- Unknown Outcome Records        : 1
-- Supplier OTD Rate              : 88.61%
--
-- MATHEMATICAL VALIDATION:
-- OTD Rate = 646 / 729 * 100 = 88.61%
-- Confirmed Late = 729 - 646 = 83
-- Total Recorded = 729 + 1 = 730
--
-- BUSINESS INTERPRETATION:
-- 88.61% of eligible supplier delivery lines
-- arrived on time during October 2026.
--
-- Confirmed late delivery rate was 11.39%.
--
-- MANAGEMENT IMPLICATION:
-- Investigate suppliers with below-target delivery
-- performance and examine whether reliability
-- problems overlap with inventory shortages.
--
-- LIMITATIONS:
-- 1. One delivery line has an unknown outcome.
-- 2. Unknown outcomes are excluded from the OTD rate.
-- 3. OTD measures delivery-line reliability.
-- 4. This KPI alone does not establish stockout causes.
-- 5. Supplier-level rankings require further analysis.
--
-- HISTORICAL ANALYSIS:
-- All 12 reporting months will be analyzed separately
-- in 04_monthly_trends.sql.
--
-- VALIDATION STATUS:
-- October results verified against MySQL output.
-- SQL-Python reconciliation remains pending.
-- =========================================================
-- =========================================================
-- KPI 05: AVERAGE SUPPLIER LEAD TIME
-- =========================================================
--
-- BUSINESS QUESTION:
-- How many days do supplier replenishments take
-- on average during October 2026?
--
-- REPORTING GRAIN:
-- One SKU x Warehouse x Reporting Month
--
-- NUMERATOR:
-- SUM(Observed Lead Time * Delivery Count)
--
-- DENOMINATOR:
-- SUM(Delivery Count) for records with valid
-- observed lead-time measurements.
--
-- FORMULA:
-- Weighted Average Lead Time =
-- SUM(Lead Time * Delivery Count)
-- / SUM(Eligible Delivery Count)
--
-- NULL HANDLING:
-- Exclude delivery lines with missing lead times.
-- Zero-delivery records have no observed lead time
-- and do not contribute to the calculation.
--
-- BUSINESS USE:
-- Measure replenishment speed and support inventory
-- planning, reorder policy and supplier comparisons.
--
-- LIMITATIONS:
-- 1. This is a delivery-line-weighted estimate.
-- 2. Missing observed lead times are excluded.
-- 3. Monthly aggregates cannot reveal individual
--    shipment lead-time variation.
-- 4. Longer lead time does not prove stockout causality.
-- =========================================================

WITH lead_time_summary AS (

    SELECT

        SUM(supplier_deliveries_count)
            AS total_delivery_lines,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_delivery_lines,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NOT NULL
                THEN replenishment_lead_time_days
                     * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS excluded_delivery_lines,

        SUM(
            CASE
                WHEN supplier_deliveries_count = 0
                THEN 1 ELSE 0
            END
        ) AS zero_delivery_records,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_lead_time_records

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Recorded Delivery Lines' AS metric,
       total_delivery_lines AS value
FROM lead_time_summary

UNION ALL

SELECT 'Eligible Delivery Lines',
       eligible_delivery_lines
FROM lead_time_summary

UNION ALL

SELECT 'Excluded Delivery Lines',
       excluded_delivery_lines
FROM lead_time_summary

UNION ALL

SELECT 'Records With Zero Deliveries',
       zero_delivery_records
FROM lead_time_summary

UNION ALL

SELECT 'Records With Missing Lead Time',
       missing_lead_time_records
FROM lead_time_summary

UNION ALL

SELECT 'Weighted Lead-Day Total',
       weighted_lead_days
FROM lead_time_summary

UNION ALL

SELECT 'Average Supplier Lead Time (Days)',
       ROUND(
           weighted_lead_days /
           NULLIF(eligible_delivery_lines, 0), 2
       )
FROM lead_time_summary

UNION ALL

SELECT 'Delivery Line Reconciliation',
       eligible_delivery_lines + excluded_delivery_lines
FROM lead_time_summary;
-- =========================================================
-- KPI 05: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- Reporting Period: October 2026
-- Data Source: Cleaned Synthetic Inventory Dataset
-- Reporting Grain: SKU x Warehouse x Month
-- Measurement Unit: Days
--
-- KPI DEFINITION:
-- Delivery-line-weighted average observed lead time
-- for replenishments with known lead-time measurements.
--
-- VERIFIED SQL RESULTS:
-- Total Recorded Delivery Lines    : 730
-- Eligible Delivery Lines          : 729
-- Excluded Delivery Lines          : 1
-- Records With Zero Deliveries     : 68
-- Records With Missing Lead Time   : 1
-- Weighted Lead-Day Total          : 7920.00
-- Average Supplier Lead Time       : 10.86 days
-- Delivery Line Reconciliation     : 730
--
-- FORMULA:
-- Weighted Average Lead Time =
-- SUM(Lead Time Days * Delivery Count)
-- / SUM(Eligible Delivery Count)
--
-- MATHEMATICAL VERIFICATION:
-- 7920 / 729 = 10.8641975...
-- Rounded Average = 10.86 days
--
-- Delivery Reconciliation:
-- 729 eligible + 1 excluded = 730 recorded
--
-- BUSINESS INTERPRETATION:
-- Eligible supplier replenishment delivery lines
-- took approximately 10.86 days on average
-- during October 2026.
--
-- MANAGEMENT IMPLICATION:
-- Compare observed lead time against contractual
-- lead times, product demand, inventory coverage
-- and supplier reliability.
--
-- Investigate suppliers whose replenishment times
-- may place high-demand SKUs at greater risk.
--
-- ASSUMPTIONS:
-- 1. Each row's observed lead time represents
--    the average duration of its delivery lines.
-- 2. Each eligible delivery line receives equal
--    weight in the overall KPI.
--
-- NULL HANDLING:
-- 1. Records with zero deliveries contribute
--    no weight to the average.
-- 2. One delivery line with unknown lead time
--    is excluded from numerator and denominator.
-- 3. Missing measurements are not treated as zero.
--
-- LIMITATIONS:
-- 1. The dataset contains aggregated observations,
--    not individual shipment timestamps.
-- 2. The weighted result depends on the
--    row-level lead-time averages.
-- 3. The average does not measure variability,
--    maximum lead time or supplier consistency.
-- 4. No conclusion about contractual compliance
--    is made without benchmarking.
-- 5. Lead time alone does not prove stockout causes.
--
-- FUTURE ANALYSIS:
-- 04_monthly_trends.sql:
-- Compare lead-time performance over 12 months.
--
-- 06_supplier_performance.sql:
-- Compare observed versus contracted lead time
-- and investigate supplier-level differences.
--
-- VALIDATION STATUS:
-- October SQL results and arithmetic verified.
-- Independent SQL-Python reconciliation pending.
-- =========================================================
-- =========================================================
-- KPI 06: CLOSING INVENTORY VALUE
-- =========================================================
--
-- BUSINESS QUESTION:
-- What is the total acquisition-cost value of
-- inventory remaining at the end of October 2026?
--
-- REPORTING PERIOD:
-- October 2026
--
-- REPORTING GRAIN:
-- One SKU x One Warehouse x One Month
--
-- FORMULA:
-- Closing Inventory Value =
-- SUM(Closing Stock Units * Unit Cost)
--
-- SOURCE FIELDS:
-- closing_stock_units
-- unit_cost
--
-- CROSS-CHECK FIELD:
-- closing_inventory_value
--
-- BUSINESS PURPOSE:
-- Quantify capital tied up in inventory and support
-- warehouse, category and replenishment analysis.
--
-- ASSUMPTIONS:
-- 1. Unit cost represents the synthetic dataset's
--    acquisition cost for each SKU-location record.
-- 2. Closing inventory values are non-negative.
-- 3. This is a month-end inventory snapshot.
--
-- LIMITATIONS:
-- 1. Inventory value is not sales revenue or profit.
-- 2. It does not represent market selling value.
-- 3. It is not an audited accounting valuation.
-- 4. Monthly closing balances must not be summed
--    together as an annual closing inventory value.
-- =========================================================

WITH october_inventory_value AS (

    SELECT

        COUNT(*) AS total_locations,

        SUM(closing_stock_units)
            AS total_closing_units,

        SUM(
            closing_stock_units * unit_cost
        ) AS recalculated_value_inr,

        SUM(closing_inventory_value)
            AS stored_value_inr,

        SUM(
            CASE
                WHEN ABS(
                    closing_inventory_value
                    - (closing_stock_units * unit_cost)
                ) > 0.01
                THEN 1
                ELSE 0
            END
        ) AS mismatched_records,

        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1
                ELSE 0
            END
        ) AS zero_stock_locations

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM october_inventory_value

UNION ALL

SELECT 'Total Closing Stock Units',
       total_closing_units
FROM october_inventory_value

UNION ALL

SELECT 'Recalculated Inventory Value (INR)',
       ROUND(recalculated_value_inr, 2)
FROM october_inventory_value

UNION ALL

SELECT 'Stored Inventory Value (INR)',
       ROUND(stored_value_inr, 2)
FROM october_inventory_value

UNION ALL

SELECT 'Value Difference (INR)',
       ROUND(
           stored_value_inr - recalculated_value_inr, 2
       )
FROM october_inventory_value

UNION ALL

SELECT 'Mismatched Inventory Records',
       mismatched_records
FROM october_inventory_value

UNION ALL

SELECT 'Zero Stock Locations',
       zero_stock_locations
FROM october_inventory_value

UNION ALL

SELECT 'Closing Inventory Value (Crore INR)',
       ROUND(
           recalculated_value_inr / 10000000, 2
       )
FROM october_inventory_value;
-- =========================================================
-- KPI 06: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- REPORTING PERIOD:
-- October 2026
--
-- DATA SOURCE:
-- Cleaned Synthetic Inventory Dataset
--
-- REPORTING GRAIN:
-- One SKU x One Warehouse x One Month
--
-- BUSINESS QUESTION:
-- What is the cost-based value of inventory remaining
-- at the end of the reporting month?
--
-- VERIFIED SQL RESULTS:
-- Total Inventory Locations          : 360
-- Total Closing Stock Units          : 31841
-- Recalculated Inventory Value (INR)  : 58027088.73
-- Stored Inventory Value (INR)        : 58027088.73
-- Value Difference (INR)              : 0.00
-- Mismatched Inventory Records        : 0
-- Zero Stock Locations                : 79
-- Closing Inventory Value (Crore INR) : 5.80
--
-- KPI FORMULA:
-- Closing Inventory Value =
-- SUM(Closing Stock Units * Unit Cost)
--
-- MATHEMATICAL VALIDATION:
-- 58027088.73 - 58027088.73 = 0.00 INR
--
-- 58027088.73 / 10000000 = 5.802708873 crore
-- Rounded closing inventory value = 5.80 crore
--
-- RECONCILIATION:
-- SQL independently recalculated inventory value
-- using closing_stock_units and unit_cost.
--
-- The recalculated total matches the previously
-- stored Python-derived inventory value.
--
-- Zero records had an absolute value discrepancy
-- greater than the 0.01 INR tolerance.
--
-- BUSINESS INTERPRETATION:
-- NexaDistribution held approximately INR 5.80 crore
-- in closing inventory at the end of October 2026.
--
-- The inventory comprises 31841 units across
-- 360 SKU-warehouse locations.
--
-- MANAGEMENT IMPLICATION:
-- Investigate the distribution of inventory value
-- across warehouses, categories and individual SKUs.
--
-- Compare high-value inventory holdings with:
-- 1. Inventory availability and stockout risk
-- 2. Reorder point performance
-- 3. Excess-stock exposure
-- 4. Demand and replenishment requirements
--
-- ASSUMPTIONS:
-- 1. Unit cost reflects the synthetic dataset's
--    acquisition-cost assumption.
-- 2. Closing inventory is valued using that unit cost.
-- 3. The reporting period uses month-end balances.
--
-- LIMITATIONS:
-- 1. Inventory value is not revenue or profit.
-- 2. It does not represent cash immediately available.
-- 3. It does not prove that inventory is excessive.
-- 4. It is not an audited accounting valuation.
-- 5. Monthly closing balances are snapshots and
--    must not be summed as annual closing stock.
-- 6. Aggregate equality alone is not sufficient;
--    row-level mismatches were also checked.
--
-- FUTURE ANALYSIS:
-- 04_monthly_trends.sql:
-- Month-end inventory trends.
--
-- 05_warehouse_analysis.sql:
-- Warehouse-level inventory value distribution.
--
-- 07_inventory_risk_analysis.sql:
-- Compare inventory levels with shortage risks.
--
-- 08_financial_exposure.sql:
-- Potential margin and excess-stock exposure.
--
-- VALIDATION STATUS:
-- SQL totals and row-level value checks passed.
-- Independent SQL-Python reconciliation pending.
-- =========================================================
-- =========================================================
-- KPI 07: DAYS OF INVENTORY COVERAGE
-- =========================================================
--
-- BUSINESS QUESTION:
-- How many days of demand could October's closing
-- inventory support at the observed demand rate?
--
-- REPORTING PERIOD:
-- October 2026
--
-- REPORTING GRAIN:
-- SKU x Warehouse x Month
--
-- LOCATION-LEVEL FORMULA:
-- Closing Stock Units /
-- (Monthly Demand Units / Days in Month)
--
-- PORTFOLIO-LEVEL FORMULA:
-- Total Closing Units / Total Estimated Daily Demand
--
-- BUSINESS PURPOSE:
-- Measure approximate inventory availability runway
-- and support replenishment planning.
--
-- ASSUMPTIONS:
-- 1. Demand continues at its monthly average rate.
-- 2. No additional inventory is received.
-- 3. Inventory is valued in physical units, not INR.
--
-- LIMITATIONS:
-- 1. Demand may vary from day to day.
-- 2. Future replenishment is excluded.
-- 3. Portfolio coverage can hide SKU shortages.
-- 4. Coverage alone does not establish stockout dates.
-- =========================================================

WITH coverage_summary AS (

    SELECT

        COUNT(*) AS total_locations,

        SUM(closing_stock_units)
            AS total_closing_units,

        SUM(demand_units)
            AS total_demand_units,

        MIN(days_in_month)
            AS minimum_calendar_days,

        MAX(days_in_month)
            AS maximum_calendar_days,

        SUM(
            demand_units * 1.0 /
            NULLIF(days_in_month, 0)
        ) AS estimated_daily_demand,

        SUM(
            CASE
                WHEN demand_units = 0
                THEN 1 ELSE 0
            END
        ) AS zero_demand_locations,

        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1 ELSE 0
            END
        ) AS zero_stock_locations

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM coverage_summary

UNION ALL

SELECT 'Total Closing Stock Units',
       total_closing_units
FROM coverage_summary

UNION ALL

SELECT 'Total Monthly Demand Units',
       total_demand_units
FROM coverage_summary

UNION ALL

SELECT 'Minimum Days in Month',
       minimum_calendar_days
FROM coverage_summary

UNION ALL

SELECT 'Maximum Days in Month',
       maximum_calendar_days
FROM coverage_summary

UNION ALL

SELECT 'Estimated Daily Demand (Units)',
       ROUND(estimated_daily_demand, 2)
FROM coverage_summary

UNION ALL

SELECT 'Locations With Zero Demand',
       zero_demand_locations
FROM coverage_summary

UNION ALL

SELECT 'Locations With Zero Stock',
       zero_stock_locations
FROM coverage_summary

UNION ALL

SELECT 'Portfolio Inventory Coverage (Days)',
       ROUND(
           total_closing_units /
           NULLIF(estimated_daily_demand, 0), 2
       )
FROM coverage_summary;
-- =========================================================
-- KPI 07: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- REPORTING PERIOD:
-- October 2026
--
-- BUSINESS QUESTION:
-- How many days of demand could aggregate closing
-- inventory support at the observed demand rate?
--
-- REPORTING GRAIN:
-- SKU x Warehouse x Month
--
-- VERIFIED SQL RESULTS:
-- Total Inventory Locations       : 360
-- Total Closing Stock Units       : 31841
-- Total Monthly Demand Units      : 51603
-- Minimum Days in Month           : 31
-- Maximum Days in Month           : 31
-- Estimated Daily Demand          : 1664.61 units
-- Zero-Demand Locations           : 0
-- Zero-Stock Locations            : 79
-- Portfolio Inventory Coverage    : 19.13 days
--
-- FORMULA:
-- Coverage Days =
-- SUM(Closing Stock Units) /
-- SUM(Demand Units / Days in Month)
--
-- MATHEMATICAL VALIDATION:
-- Daily Demand = 51603 / 31
--              = 1664.6129 units/day
--
-- Coverage = 31841 / (51603 / 31)
--          = 19.13 days (rounded)
--
-- CROSS-KPI VALIDATION:
-- Closing Units = 31841 (matches KPI 06)
-- Demand Units  = 51603 (matches KPI 01)
-- Zero Stock    = 79 (matches KPI 03)
-- Calendar Days = 31 (minimum and maximum)
--
-- BUSINESS INTERPRETATION:
-- Aggregate closing inventory corresponds to
-- approximately 19.13 days of October's average
-- demand rate, assuming no future replenishment.
--
-- MANAGEMENT IMPLICATION:
-- Investigate individual SKUs and warehouses
-- with limited inventory coverage.
--
-- Compare location-level coverage against
-- observed and contracted supplier lead times.
--
-- Prioritize investigation where inventory
-- coverage may be inadequate for replenishment.
--
-- ASSUMPTIONS:
-- 1. Demand continues at the October average rate.
-- 2. No future receipts or transfers are assumed.
-- 3. Inventory and demand are measured in units.
-- 4. Month-end stock is the starting inventory.
--
-- LIMITATIONS:
-- 1. Portfolio-level coverage is an aggregate proxy.
-- 2. Different SKUs are not interchangeable.
-- 3. Some individual locations already have zero stock.
-- 4. Daily demand may fluctuate.
-- 5. Actual replenishments are not modeled.
-- 6. Coverage is not a guaranteed stockout date.
-- 7. The result is not a historical average of
--    daily inventory coverage.
--
-- FUTURE INVESTIGATIONS:
-- 04_monthly_trends.sql:
-- Analyze coverage changes over 12 months.
--
-- 05_warehouse_analysis.sql:
-- Examine warehouse-level coverage differences.
--
-- 07_inventory_risk_analysis.sql:
-- Identify SKU-warehouse coverage shortages.
--
-- VALIDATION STATUS:
-- October SQL results and arithmetic verified.
-- Cross-KPI totals consistent.
-- Independent SQL-Python reconciliation pending.
-- =========================================================
-- =========================================================
-- KPI 08: MONTHLY INVENTORY TURNOVER RATIO
-- =========================================================
--
-- BUSINESS QUESTION:
-- How efficiently was inventory moved relative to
-- its average acquisition-cost value in October 2026?
--
-- REPORTING PERIOD:
-- October 2026
--
-- REPORTING GRAIN:
-- One SKU x Warehouse x Month
--
-- NUMERATOR:
-- Recalculated Fulfilled COGS Proxy =
-- SUM(fulfilled_units * unit_cost)
--
-- DENOMINATOR:
-- Average Inventory Value =
-- (Opening Inventory Value + Closing Inventory Value) / 2
--
-- KPI FORMULA:
-- Monthly Inventory Turnover =
-- Fulfilled COGS Proxy / Average Inventory Value
--
-- BUSINESS PURPOSE:
-- Evaluate inventory movement efficiency and
-- support working-capital management.
--
-- VALIDATION:
-- Compare recalculated fulfilled COGS proxy
-- with the Python-derived stored value.
--
-- ASSUMPTIONS:
-- 1. Fulfilled units approximate units sold.
-- 2. Unit cost is used to estimate COGS.
-- 3. Average inventory uses opening and closing
--    acquisition-cost values.
--
-- LIMITATIONS:
-- 1. COGS is an operational proxy, not audited COGS.
-- 2. A two-point average may hide intramonth changes.
-- 3. A higher turnover is not automatically better
--    if service levels or availability deteriorate.
-- 4. This is a monthly, not annual, turnover ratio.
-- =========================================================

WITH october_turnover AS (

    SELECT

        COUNT(*) AS total_locations,

        SUM(opening_stock_units)
            AS total_opening_units,

        SUM(closing_stock_units)
            AS total_closing_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        SUM(opening_stock_units * unit_cost)
            AS opening_inventory_value,

        SUM(closing_stock_units * unit_cost)
            AS closing_inventory_value_recalculated,

        SUM(
            (opening_stock_units + closing_stock_units)
            * unit_cost / 2.0
        ) AS average_inventory_value,

        SUM(fulfilled_units * unit_cost)
            AS recalculated_cogs_proxy,

        SUM(fulfilled_cogs_proxy)
            AS stored_cogs_proxy,

        SUM(
            CASE
                WHEN ABS(
                    fulfilled_cogs_proxy
                    - (fulfilled_units * unit_cost)
                ) > 0.01
                THEN 1
                ELSE 0
            END
        ) AS mismatched_cogs_records

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM october_turnover

UNION ALL

SELECT 'Total Opening Stock Units',
       total_opening_units
FROM october_turnover

UNION ALL

SELECT 'Total Closing Stock Units',
       total_closing_units
FROM october_turnover

UNION ALL

SELECT 'Total Fulfilled Units',
       total_fulfilled_units
FROM october_turnover

UNION ALL

SELECT 'Opening Inventory Value (INR)',
       ROUND(opening_inventory_value, 2)
FROM october_turnover

UNION ALL

SELECT 'Closing Inventory Value (INR)',
       ROUND(closing_inventory_value_recalculated, 2)
FROM october_turnover

UNION ALL

SELECT 'Average Inventory Value (INR)',
       ROUND(average_inventory_value, 2)
FROM october_turnover

UNION ALL

SELECT 'Recalculated COGS Proxy (INR)',
       ROUND(recalculated_cogs_proxy, 2)
FROM october_turnover

UNION ALL

SELECT 'Stored COGS Proxy (INR)',
       ROUND(stored_cogs_proxy, 2)
FROM october_turnover

UNION ALL

SELECT 'COGS Proxy Difference (INR)',
       ROUND(
           stored_cogs_proxy - recalculated_cogs_proxy, 2
       )
FROM october_turnover

UNION ALL

SELECT 'Mismatched COGS Records',
       mismatched_cogs_records
FROM october_turnover

UNION ALL

SELECT 'Monthly Inventory Turnover (Times)',
       ROUND(
           recalculated_cogs_proxy /
           NULLIF(average_inventory_value, 0), 2
       )
FROM october_turnover;
-- =========================================================
-- KPI 08: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- REPORTING PERIOD:
-- October 2026
--
-- KPI NAME:
-- Monthly Inventory Turnover Ratio
--
-- BUSINESS QUESTION:
-- How efficiently was inventory moved relative
-- to its average acquisition-cost value?
--
-- REPORTING GRAIN:
-- SKU x Warehouse x Month
--
-- VERIFIED SQL RESULTS:
-- Total Inventory Locations       : 360
-- Total Opening Stock Units       : 35957
-- Total Closing Stock Units       : 31841
-- Total Fulfilled Units           : 47922
-- Opening Inventory Value (INR)   : 65004327.41
-- Closing Inventory Value (INR)   : 58027088.73
-- Average Inventory Value (INR)   : 61515708.07
-- Recalculated COGS Proxy (INR)   : 89019087.59
-- Stored COGS Proxy (INR)         : 89019087.59
-- COGS Proxy Difference (INR)     : 0.00
-- Mismatched COGS Records         : 0
-- Monthly Inventory Turnover      : 1.45 times
--
-- KPI FORMULAS:
--
-- Opening Inventory Value =
-- SUM(opening_stock_units * unit_cost)
--
-- Closing Inventory Value =
-- SUM(closing_stock_units * unit_cost)
--
-- Average Inventory Value =
-- (Opening Inventory Value + Closing Inventory Value) / 2
--
-- Fulfilled COGS Proxy =
-- SUM(fulfilled_units * unit_cost)
--
-- Monthly Inventory Turnover =
-- Fulfilled COGS Proxy / Average Inventory Value
--
-- MATHEMATICAL VERIFICATION:
--
-- Average Inventory Value =
-- (65004327.41 + 58027088.73) / 2
-- = 61515708.07 INR
--
-- Monthly Turnover =
-- 89019087.59 / 61515708.07
-- = 1.45 times (rounded)
--
-- COGS Reconciliation =
-- 89019087.59 - 89019087.59
-- = 0.00 INR
--
-- CROSS-KPI CHECKS:
-- Inventory Locations = 360
-- Closing Units = 31841 (matches KPI 06)
-- Fulfilled Units = 47922 (matches KPI 01)
-- Closing Inventory Value = 58027088.73
-- (matches KPI 06)
--
-- BUSINESS INTERPRETATION:
-- During October 2026, fulfilled goods had a
-- cost equivalent to approximately 1.45 times
-- the average inventory value held.
--
-- This indicates the monthly pace of inventory
-- movement relative to average inventory holdings.
--
-- MANAGEMENT IMPLICATION:
-- Evaluate turnover by category, SKU and warehouse.
--
-- Compare turnover with:
-- 1. Fill rate and stockout performance
-- 2. Inventory coverage
-- 3. Reorder thresholds
-- 4. Excess-stock exposure
-- 5. Monthly historical patterns
--
-- ASSUMPTIONS:
-- 1. Fulfilled units approximate units sold.
-- 2. Unit cost represents acquisition cost.
-- 3. Fulfilled COGS is a calculated proxy.
-- 4. Average inventory uses opening and
--    closing cost-based balances.
--
-- LIMITATIONS:
-- 1. Fulfilled COGS is not audited financial COGS.
-- 2. Inventory averages use only two balance points.
-- 3. The KPI measures monthly, not annual turnover.
-- 4. Higher turnover does not automatically
--    imply better inventory performance.
-- 5. Turnover alone cannot identify excess stock
--    or explain individual SKU shortages.
-- 6. An annual turnover ratio requires a separately
--    defined annual COGS and inventory denominator.
--
-- FUTURE ANALYSIS:
-- 04_monthly_trends.sql:
-- Analyze monthly turnover performance.
--
-- 05_warehouse_analysis.sql:
-- Compare warehouse inventory efficiency.
--
-- 07_inventory_risk_analysis.sql:
-- Investigate slow-moving and at-risk SKUs.
--
-- VALIDATION STATUS:
-- October SQL results mathematically verified.
-- Stored and independently recalculated COGS agree.
-- Row-level differences checked at 0.01 INR tolerance.
-- Independent SQL-Python reconciliation pending.
-- =========================================================
-- =========================================================
-- KPI 09: UNFULFILLED CUSTOMER DEMAND
-- =========================================================
--
-- BUSINESS QUESTION:
-- How many customer-requested units were not fulfilled
-- during October 2026?
--
-- REPORTING PERIOD:
-- October 2026
--
-- REPORTING GRAIN:
-- One SKU x One Warehouse x One Month
--
-- PRIMARY FORMULA:
-- Unfulfilled Units =
-- SUM(demand_units - fulfilled_units)
--
-- SUPPORTING FORMULA:
-- Unfulfilled Demand Rate (%) =
-- Total Unfulfilled Units / Total Demand Units * 100
--
-- VALIDATION:
-- Compare SQL-recalculated unfulfilled units
-- against the Python-derived unfulfilled_units field.
--
-- BUSINESS PURPOSE:
-- Measure the size and rate of demand-fulfillment
-- shortfalls and guide investigation priorities.
--
-- LIMITATIONS:
-- 1. Unfulfilled demand is not confirmed lost sales.
-- 2. This measure alone does not identify root causes.
-- 3. Stockouts and unfulfilled demand are different KPIs.
-- 4. Financial exposure requires a separate estimate.
-- =========================================================

WITH demand_summary AS (

    SELECT

        COUNT(*) AS total_locations,

        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        SUM(demand_units - fulfilled_units)
            AS recalculated_unfulfilled_units,

        SUM(unfulfilled_units)
            AS stored_unfulfilled_units,

        SUM(
            CASE
                WHEN unfulfilled_units <>
                     (demand_units - fulfilled_units)
                THEN 1
                ELSE 0
            END
        ) AS mismatched_records,

        SUM(
            CASE
                WHEN demand_units > fulfilled_units
                THEN 1
                ELSE 0
            END
        ) AS locations_with_unfulfilled_demand

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM demand_summary

UNION ALL

SELECT 'Total Customer Demand Units',
       total_demand_units
FROM demand_summary

UNION ALL

SELECT 'Total Fulfilled Units',
       total_fulfilled_units
FROM demand_summary

UNION ALL

SELECT 'Recalculated Unfulfilled Units',
       recalculated_unfulfilled_units
FROM demand_summary

UNION ALL

SELECT 'Stored Unfulfilled Units',
       stored_unfulfilled_units
FROM demand_summary

UNION ALL

SELECT 'Unfulfilled Units Difference',
       stored_unfulfilled_units
       - recalculated_unfulfilled_units
FROM demand_summary

UNION ALL

SELECT 'Mismatched Inventory Records',
       mismatched_records
FROM demand_summary

UNION ALL

SELECT 'Locations With Unfulfilled Demand',
       locations_with_unfulfilled_demand
FROM demand_summary

UNION ALL

SELECT 'Unfulfilled Demand Rate (%)',
       ROUND(
           recalculated_unfulfilled_units * 100.0 /
           NULLIF(total_demand_units, 0), 2
       )
FROM demand_summary

UNION ALL

SELECT 'Fill Rate Cross-Check (%)',
       ROUND(
           total_fulfilled_units * 100.0 /
           NULLIF(total_demand_units, 0), 2
       )
FROM demand_summary

UNION ALL

SELECT 'Demand Reconciliation',
       total_fulfilled_units
       + recalculated_unfulfilled_units
FROM demand_summary;
-- =========================================================
-- KPI 09: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- REPORTING PERIOD:
-- October 2026
--
-- DATA SOURCE:
-- Cleaned Synthetic Inventory Dataset
--
-- REPORTING GRAIN:
-- One SKU x One Warehouse x One Month
--
-- BUSINESS QUESTION:
-- How many units of customer demand were not fulfilled?
--
-- PRIMARY KPI:
-- Total Unfulfilled Demand (Units)
--
-- SUPPORTING KPIs:
-- Unfulfilled Demand Rate (%)
-- Locations With Unfulfilled Demand
--
-- VERIFIED SQL RESULTS:
-- Total Inventory Locations        : 360
-- Total Customer Demand Units      : 51603
-- Total Fulfilled Units            : 47922
-- Recalculated Unfulfilled Units   : 3681
-- Stored Unfulfilled Units         : 3681
-- Unfulfilled Units Difference     : 0
-- Mismatched Inventory Records     : 0
-- Locations With Unfulfilled Demand: 79
-- Unfulfilled Demand Rate          : 7.13%
-- Fill Rate Cross-Check            : 92.87%
-- Demand Reconciliation            : 51603
--
-- KPI FORMULAS:
--
-- Unfulfilled Demand =
-- SUM(demand_units - fulfilled_units)
--
-- Unfulfilled Demand Rate (%) =
-- SUM(unfulfilled_units) /
-- SUM(demand_units) * 100
--
-- MATHEMATICAL VALIDATION:
--
-- Unfulfilled Units =
-- 51603 - 47922 = 3681
--
-- Unfulfilled Demand Rate =
-- 3681 / 51603 * 100 = 7.13%
--
-- Fill Rate Cross-Check =
-- 47922 / 51603 * 100 = 92.87%
--
-- Rate Reconciliation =
-- 92.87% + 7.13% = 100.00%
--
-- Unit Reconciliation =
-- 47922 + 3681 = 51603
--
-- Stored vs Recalculated Difference =
-- 3681 - 3681 = 0
--
-- Row-Level Mismatches = 0
--
-- BUSINESS INTERPRETATION:
-- NexaDistribution fulfilled 47922 out of 51603
-- requested units during October 2026.
--
-- A total of 3681 requested units remained
-- unfulfilled, representing 7.13% of demand.
--
-- Demand shortfalls affected 79 SKU-warehouse
-- locations.
--
-- MANAGEMENT IMPLICATION:
-- 1. Rank warehouses by unfulfilled demand.
-- 2. Identify SKUs responsible for major shortfalls.
-- 3. Examine supplier reliability and lead times.
-- 4. Compare shortfalls with inventory coverage.
-- 5. Quantify potential gross-margin exposure.
--
-- CROSS-KPI OBSERVATION:
-- KPI 02 Stockout Locations = 79
-- KPI 03 Zero-Stock Locations = 79
-- KPI 09 Unfulfilled Demand Locations = 79
--
-- These equal counts DO NOT establish that
-- they represent identical SKU-warehouse records.
--
-- Record-level overlap requires further analysis.
--
-- ASSUMPTIONS:
-- 1. Demand and fulfillment refer to units.
-- 2. The same reporting period is used throughout.
-- 3. Unfulfilled = Demand - Fulfilled.
-- 4. Source data represents the synthetic
--    business scenario.
--
-- LIMITATIONS:
-- 1. Unfulfilled demand is not confirmed lost sales.
-- 2. Demand might be backordered or fulfilled later.
-- 3. This KPI does not independently identify causes.
-- 4. Location counts do not measure financial impact.
-- 5. Financial exposure is estimated separately.
-- 6. Aggregated monthly records limit event-level
--    investigation.
--
-- FUTURE ANALYSIS:
-- 04_monthly_trends.sql:
-- Investigate unfulfilled demand over 12 months.
--
-- 05_warehouse_analysis.sql:
-- Rank warehouses by demand shortfall.
--
-- 07_inventory_risk_analysis.sql:
-- Investigate SKU-level shortages and overlaps.
--
-- 08_financial_exposure.sql:
-- Estimate potential margin exposure.
--
-- VALIDATION STATUS:
-- October SQL outputs and arithmetic verified.
-- Stored and recalculated unfulfilled units agree.
-- Row-level mismatch check passed.
-- Independent SQL-Python reconciliation pending.
-- =========================================================
-- =========================================================
-- KPI 10: POTENTIAL GROSS-MARGIN EXPOSURE
-- =========================================================
--
-- BUSINESS QUESTION:
-- How much potential gross margin is associated
-- with unfulfilled demand during October 2026?
--
-- REPORTING PERIOD:
-- October 2026
--
-- REPORTING GRAIN:
-- One SKU x One Warehouse x One Month
--
-- FORMULA:
-- Unfulfilled Units = Demand Units - Fulfilled Units
--
-- Unit Margin = Selling Price - Unit Cost
--
-- Positive Margin Opportunity =
-- Unfulfilled Units * GREATEST(Unit Margin, 0)
--
-- Portfolio Potential Gross-Margin Exposure =
-- SUM(Positive Margin Opportunity)
--
-- VALIDATION:
-- Compare recalculated margin exposure with
-- the Python-derived potential_margin_exposure.
--
-- IMPORTANT:
-- If the stored and recalculated definitions differ,
-- investigate the original Python calculation
-- before accepting the KPI.
--
-- ASSUMPTIONS:
-- 1. Recorded prices and costs apply to unmet units.
-- 2. Unfulfilled units represent potential demand.
-- 3. Only positive unit-margin opportunities count.
--
-- LIMITATIONS:
-- 1. This is not confirmed lost profit.
-- 2. This is not audited financial gross margin.
-- 3. Unfulfilled orders may be recovered later.
-- 4. Additional selling and fulfillment costs
--    are not included.
-- =========================================================

WITH october_margin AS (

    SELECT
        inventory_record_id,

        demand_units - fulfilled_units
            AS unfulfilled_units_recalculated,

        unit_selling_price,

        unit_cost,

        unit_selling_price - unit_cost
            AS unit_margin,

        (
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost, 0
            )
        ) AS recalculated_margin_exposure,

        potential_margin_exposure
            AS stored_margin_exposure

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

margin_summary AS (

    SELECT

        COUNT(*) AS total_locations,

        SUM(unfulfilled_units_recalculated)
            AS total_unfulfilled_units,

        SUM(
            CASE
                WHEN unfulfilled_units_recalculated > 0
                THEN 1 ELSE 0
            END
        ) AS locations_with_unfulfilled_demand,

        SUM(
            unfulfilled_units_recalculated
            * unit_selling_price
        ) AS potential_sales_value,

        SUM(
            unfulfilled_units_recalculated
            * unit_cost
        ) AS associated_cost_proxy,

        SUM(recalculated_margin_exposure)
            AS recalculated_total_exposure,

        SUM(stored_margin_exposure)
            AS stored_total_exposure,

        SUM(
            CASE
                WHEN ABS(
                    recalculated_margin_exposure
                    - stored_margin_exposure
                ) > 0.01
                THEN 1 ELSE 0
            END
        ) AS mismatched_records,

        SUM(
            CASE
                WHEN unfulfilled_units_recalculated > 0
                 AND unit_margin <= 0
                THEN 1 ELSE 0
            END
        ) AS affected_nonpositive_margin_locations

    FROM october_margin

)

SELECT 'Total Inventory Locations' AS metric,
       total_locations AS value
FROM margin_summary

UNION ALL

SELECT 'Total Unfulfilled Demand Units',
       total_unfulfilled_units
FROM margin_summary

UNION ALL

SELECT 'Locations With Unfulfilled Demand',
       locations_with_unfulfilled_demand
FROM margin_summary

UNION ALL

SELECT 'Potential Selling Value (INR)',
       ROUND(potential_sales_value, 2)
FROM margin_summary

UNION ALL

SELECT 'Associated Unit-Cost Proxy (INR)',
       ROUND(associated_cost_proxy, 2)
FROM margin_summary

UNION ALL

SELECT 'Recalculated Gross-Margin Exposure (INR)',
       ROUND(recalculated_total_exposure, 2)
FROM margin_summary

UNION ALL

SELECT 'Stored Gross-Margin Exposure (INR)',
       ROUND(stored_total_exposure, 2)
FROM margin_summary

UNION ALL

SELECT 'Exposure Difference (INR)',
       ROUND(
           stored_total_exposure
           - recalculated_total_exposure, 2
       )
FROM margin_summary

UNION ALL

SELECT 'Mismatched Exposure Records',
       mismatched_records
FROM margin_summary

UNION ALL

SELECT 'Affected Locations With Nonpositive Margin',
       affected_nonpositive_margin_locations
FROM margin_summary

UNION ALL

SELECT 'Gross-Margin Exposure (Lakh INR)',
       ROUND(
           recalculated_total_exposure / 100000, 2
       )
FROM margin_summary

UNION ALL

SELECT 'Potential Margin Per Unfulfilled Unit (INR)',
       ROUND(
           recalculated_total_exposure /
           NULLIF(total_unfulfilled_units, 0), 2
       )
FROM margin_summary;
-- =========================================================
-- KPI 10: VERIFIED RESULTS AND BUSINESS INTERPRETATION
-- =========================================================
--
-- PROJECT: SUPPLY CHAIN AI CONTROL TOWER
-- BUSINESS: NexaDistribution (Synthetic Scenario)
-- REPORTING PERIOD: October 2026
-- REPORTING GRAIN: SKU x Warehouse x Month
--
-- KPI NAME:
-- Potential Gross-Margin Exposure
--
-- BUSINESS QUESTION:
-- What potential gross margin is associated with
-- customer demand that remained unfulfilled?
--
-- PRIMARY FORMULA:
-- Unfulfilled Units = Demand Units - Fulfilled Units
--
-- Unit Gross Margin =
-- Unit Selling Price - Unit Cost
--
-- Positive Unit Margin =
-- GREATEST(Unit Gross Margin, 0)
--
-- Potential Gross-Margin Exposure =
-- SUM(Unfulfilled Units * Positive Unit Margin)
--
-- VERIFIED SQL RESULTS:
-- Total Inventory Locations          : 360
-- Total Unfulfilled Demand Units     : 3681
-- Locations With Unfulfilled Demand  : 79
-- Potential Selling Value (INR)      : 9356605.50
-- Associated Unit-Cost Proxy (INR)   : 6285399.67
-- Recalculated Margin Exposure (INR) : 3071205.83
-- Stored Margin Exposure (INR)       : 3071205.83
-- Exposure Difference (INR)          : 0.00
-- Mismatched Exposure Records        : 0
-- Nonpositive-Margin Locations       : 0
-- Margin Exposure (Lakh INR)         : 30.71
-- Potential Margin Per Unmet Unit    : 834.34
--
-- MATHEMATICAL VALIDATION:
--
-- Potential Selling Value =
-- 9356605.50 INR
--
-- Associated Unit-Cost Proxy =
-- 6285399.67 INR
--
-- Gross-Margin Exposure =
-- 9356605.50 - 6285399.67
-- = 3071205.83 INR
--
-- Note: This subtraction reconciles because
-- no affected location has nonpositive unit margin.
--
-- Exposure in Lakh INR =
-- 3071205.83 / 100000
-- = 30.71 lakh (rounded)
--
-- Potential Margin Per Unfulfilled Unit =
-- 3071205.83 / 3681
-- = 834.34 INR (rounded)
--
-- RECONCILIATION:
--
-- Stored Exposure - Recalculated Exposure =
-- 3071205.83 - 3071205.83
-- = 0.00 INR
--
-- Row-Level Mismatches (> 0.01 INR) = 0
--
-- CROSS-KPI VALIDATION:
-- Unfulfilled Units = 3681 (matches KPI 09)
-- Affected Locations = 79 (matches KPI 09)
--
-- BUSINESS INTERPRETATION:
-- In October 2026, 3681 units of customer demand
-- remained unfulfilled across 79 SKU-warehouse
-- locations.
--
-- These units represented potential selling value
-- of approximately INR 93.57 lakh.
--
-- The associated acquisition-cost proxy was
-- approximately INR 62.85 lakh.
--
-- Estimated positive gross-margin opportunity
-- was approximately INR 30.71 lakh.
--
-- MANAGEMENT IMPLICATION:
-- 1. Rank products by margin exposure.
-- 2. Rank warehouses by financial exposure.
-- 3. Identify high-demand, high-margin shortages.
-- 4. Examine supplier reliability and lead time.
-- 5. Prioritize evidence-backed replenishment actions.
-- 6. Monitor fulfillment and exposure after action.
--
-- ASSUMPTIONS:
-- 1. Recorded selling prices apply to unmet units.
-- 2. Recorded unit costs apply to unmet units.
-- 3. Unfulfilled quantities are potential sales.
-- 4. Positive unit margins are used.
-- 5. Product-level margin is approximated by
--    selling price minus unit cost.
--
-- LIMITATIONS:
-- 1. Exposure is NOT confirmed lost profit.
-- 2. Exposure is NOT confirmed lost revenue.
-- 3. Some customer demand may be recovered later.
-- 4. Additional selling, shipping and fulfillment
--    expenses are excluded.
-- 5. No actual customer cancellations are tracked.
-- 6. Supplier causality cannot be established
--    using this KPI alone.
-- 7. Monthly aggregation prevents detailed
--    investigation of individual order events.
-- 8. Values come from a synthetic business dataset.
--
-- FUTURE ANALYSIS:
--
-- 04_monthly_trends.sql:
-- Track potential exposure over all 12 months.
--
-- 05_warehouse_analysis.sql:
-- Rank warehouses by financial opportunity.
--
-- 07_inventory_risk_analysis.sql:
-- Identify shortage and replenishment risks.
--
-- 08_financial_exposure.sql:
-- Rank SKUs and categories by financial exposure.
--
-- VALIDATION STATUS:
-- October KPI 10 calculation verified.
-- All 12 SQL outputs reviewed.
-- Row-level exposure discrepancies = 0.
-- Independent SQL-Python reconciliation pending.
-- =========================================================