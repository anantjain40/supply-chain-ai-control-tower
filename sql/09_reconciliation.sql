-- =============================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 09: INDEPENDENT DATA RECONCILIATION & FINAL SQL QA
-- SECTION 09.1: DATABASE INTEGRITY & SQL BASELINE
-- Database: supply_chain_ai_db | MySQL 8
--
-- Business grain: (sku_id, warehouse, reporting_month).
-- No inventory_id column is required.
--
-- This section checks the database. A separate comparison with
-- inventory_clean.csv and suppliers_clean.csv is Section 09.2.
-- Read-only: no data is changed.
-- Expected: 44 QA rules; 30 metric/value rows.
-- =============================================================

WITH inventory_summary AS (

    SELECT
        COUNT(*) AS inventory_rows,

        COUNT(DISTINCT sku_id, warehouse, reporting_month)
            AS unique_inventory_keys,

        COUNT(DISTINCT sku_id) AS distinct_skus,

        COUNT(DISTINCT warehouse) AS distinct_warehouses,

        COUNT(DISTINCT reporting_month) AS distinct_months,

        COUNT(DISTINCT sku_id, warehouse) AS distinct_locations,

        MIN(reporting_month) AS first_month,

        MAX(reporting_month) AS last_month,

        SUM(
            CASE
                WHEN reporting_month IS NULL
                  OR DAY(reporting_month) <> 1
                THEN 1 ELSE 0
            END
        ) AS invalid_month_records,

        SUM(
            CASE
                WHEN sku_id IS NULL OR TRIM(sku_id) = ''
                  OR warehouse IS NULL OR TRIM(warehouse) = ''
                  OR supplier_id IS NULL OR TRIM(supplier_id) = ''
                  OR reporting_month IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_key_records,

        SUM(
            CASE
                WHEN product_name IS NULL
                  OR TRIM(product_name) = ''
                  OR category IS NULL
                  OR TRIM(category) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_product_details,

        SUM(
            CASE
                WHEN opening_stock_units IS NULL
                  OR received_units IS NULL
                  OR demand_units IS NULL
                  OR fulfilled_units IS NULL
                  OR closing_stock_units IS NULL
                  OR reorder_point_units IS NULL
                  OR stockout_days IS NULL
                  OR unit_cost IS NULL
                  OR unit_selling_price IS NULL
                  OR supplier_deliveries_count IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_required_numbers,

        SUM(
            CASE
                WHEN opening_stock_units < 0
                  OR received_units < 0
                  OR demand_units < 0
                  OR fulfilled_units < 0
                  OR closing_stock_units < 0
                  OR reorder_point_units < 0
                  OR stockout_days < 0
                THEN 1 ELSE 0
            END
        ) AS negative_quantity_records,

        SUM(
            CASE
                WHEN fulfilled_units > demand_units
                THEN 1 ELSE 0
            END
        ) AS overfulfilled_records,

        SUM(
            CASE
                WHEN opening_stock_units + received_units
                   - fulfilled_units <> closing_stock_units
                THEN 1 ELSE 0
            END
        ) AS inventory_balance_errors,

        SUM(
            CASE
                WHEN unit_cost <= 0
                  OR unit_selling_price <= 0
                THEN 1 ELSE 0
            END
        ) AS invalid_price_records,

        -- Unknown on-time outcomes are allowed as NULL.
        SUM(
            CASE
                WHEN supplier_deliveries_count < 0
                  OR supplier_on_time_deliveries_count < 0
                  OR supplier_on_time_deliveries_count
                     > supplier_deliveries_count
                THEN 1 ELSE 0
            END
        ) AS invalid_delivery_counts,

        SUM(
            CASE
                WHEN supplier_on_time_deliveries_count IS NULL
                THEN 1 ELSE 0
            END
        ) AS unknown_ontime_records,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_lead_time_with_deliveries,

        SUM(
            CASE
                WHEN stockout_days > DAY(LAST_DAY(reporting_month))
                THEN 1 ELSE 0
            END
        ) AS impossible_stockout_days,

        SUM(demand_units - fulfilled_units)
            AS historical_unfulfilled_units,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS historical_stockout_location_months,

        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(unit_selling_price - unit_cost, 0)
        ) AS historical_margin_exposure_inr

    FROM supply_chain_ai_db.inventory
),

-- =============================================================
-- STEP 2: SUPPLIER MASTER VALIDATION
-- =============================================================

supplier_summary AS (

    SELECT
        COUNT(*) AS supplier_rows,

        COUNT(DISTINCT supplier_id) AS unique_supplier_ids,

        SUM(
            CASE
                WHEN supplier_id IS NULL
                  OR TRIM(supplier_id) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_supplier_ids

    FROM supply_chain_ai_db.suppliers
),

-- =============================================================
-- STEP 3: DUPLICATE BUSINESS-GRAIN VALIDATION
-- =============================================================

duplicate_summary AS (

    SELECT
        COALESCE(SUM(row_count - 1), 0)
            AS duplicate_grain_rows

    FROM (

        SELECT
            sku_id,
            warehouse,
            reporting_month,
            COUNT(*) AS row_count

        FROM supply_chain_ai_db.inventory

        GROUP BY
            sku_id,
            warehouse,
            reporting_month

        HAVING COUNT(*) > 1

    ) AS duplicates_found
),

-- =============================================================
-- STEP 4: MONTHLY COMPLETENESS
-- =============================================================

monthly_summary AS (

    SELECT
        COUNT(*) AS incomplete_reporting_months

    FROM (

        SELECT reporting_month

        FROM supply_chain_ai_db.inventory

        GROUP BY reporting_month

        HAVING COUNT(*) <> 360

    ) AS wrong_month_sizes
),

-- =============================================================
-- STEP 5: SUPPLIER RELATIONSHIP VALIDATION
-- =============================================================

supplier_relationship_summary AS (

    SELECT
        COUNT(*) AS unmatched_supplier_records

    FROM supply_chain_ai_db.inventory AS i

    LEFT JOIN supply_chain_ai_db.suppliers AS s
        ON i.supplier_id = s.supplier_id

    WHERE s.supplier_id IS NULL
),

-- =============================================================
-- STEP 6: HISTORICAL LOCATION COMPLETENESS
-- =============================================================

historical_locations AS (

    SELECT
        sku_id,
        warehouse,

        COUNT(DISTINCT reporting_month)
            AS months_observed,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_months

    FROM supply_chain_ai_db.inventory

    GROUP BY
        sku_id,
        warehouse
),

historical_summary AS (

    SELECT
        COUNT(*) AS historical_locations,

        SUM(
            CASE
                WHEN months_observed <> 12
                THEN 1 ELSE 0
            END
        ) AS incomplete_location_histories,

        SUM(
            CASE
                WHEN stockout_months >= 2
                THEN 1 ELSE 0
            END
        ) AS recurring_stockout_locations

    FROM historical_locations
),

-- =============================================================
-- STEP 7: OCTOBER OPERATIONAL & FINANCIAL BASELINE
-- =============================================================

october_summary AS (

    SELECT
        COUNT(*) AS october_records,

        SUM(demand_units) AS october_demand,

        SUM(fulfilled_units) AS october_fulfilled,

        SUM(demand_units - fulfilled_units)
            AS october_unfulfilled,

        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1 ELSE 0
            END
        ) AS october_zero_stock,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS october_below_reorder,

        SUM(
            CASE
                WHEN closing_stock_units >= reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS october_healthy,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS october_stockout_locations,

        SUM(stockout_days)
            AS october_stockout_days,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN reorder_point_units - closing_stock_units
                ELSE 0
            END
        ) AS october_reorder_gap,

        SUM(
            (demand_units - fulfilled_units)
            * unit_selling_price
        ) AS october_unmet_sales,

        SUM(
            (demand_units - fulfilled_units)
            * unit_cost
        ) AS october_unmet_cost,

        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(unit_selling_price - unit_cost, 0)
        ) AS october_margin_exposure

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'
),

-- =============================================================
-- STEP 8: COMBINE AUDIT MEASURES
-- =============================================================

audit_metrics AS (

    SELECT *

    FROM inventory_summary

    CROSS JOIN supplier_summary

    CROSS JOIN duplicate_summary

    CROSS JOIN monthly_summary

    CROSS JOIN supplier_relationship_summary

    CROSS JOIN historical_summary

    CROSS JOIN october_summary
),

-- =============================================================
-- STEP 9: FINAL 44 VALIDATION RULES
-- 0 = PASS, 1 = FAIL
-- =============================================================

validation_rules AS (

    SELECT 1 AS id, 'Inventory rows' AS rule_name,
        IF(inventory_rows = 4320, 0, 1) AS failed
    FROM audit_metrics

    UNION ALL SELECT 2, 'Supplier rows',
        IF(supplier_rows = 12, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 3, 'Unique inventory business keys',
        IF(unique_inventory_keys = 4320, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 4, 'Unique supplier IDs',
        IF(unique_supplier_ids = 12, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 5, 'Distinct SKUs',
        IF(distinct_skus = 120, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 6, 'Distinct warehouses',
        IF(distinct_warehouses = 3, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 7, 'Reporting months',
        IF(distinct_months = 12, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 8, 'Reporting period boundaries',
        IF(
            first_month = '2025-11-01'
            AND last_month = '2026-10-01',
            0, 1
        )
    FROM audit_metrics

    UNION ALL SELECT 9, 'SKU-warehouse locations',
        IF(distinct_locations = 360, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 10, 'No duplicate business-grain rows',
        IF(duplicate_grain_rows = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 11, 'Complete months of 360 records',
        IF(incomplete_reporting_months = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 12, 'Month dates begin on day one',
        IF(invalid_month_records = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 13, 'Required inventory business keys',
        IF(missing_key_records = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 14, 'Required product details',
        IF(missing_product_details = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 15, 'Required numeric fields',
        IF(missing_required_numbers = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 16, 'Nonnegative inventory quantities',
        IF(negative_quantity_records = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 17, 'Fulfillment does not exceed demand',
        IF(overfulfilled_records = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 18, 'Opening-received-fulfilled-closing balance',
        IF(inventory_balance_errors = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 19, 'Positive unit costs and prices',
        IF(invalid_price_records = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 20, 'Supplier delivery counts valid',
        IF(invalid_delivery_counts = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 21, 'Stockout days within month length',
        IF(impossible_stockout_days = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 22, 'Nonmissing supplier master IDs',
        IF(missing_supplier_ids = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 23, 'All inventory suppliers matched',
        IF(unmatched_supplier_records = 0, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 24, 'Twelve months for all locations',
        IF(
            historical_locations = 360
            AND incomplete_location_histories = 0,
            0, 1
        )
    FROM audit_metrics

    UNION ALL SELECT 25, 'Recurring stockout locations',
        IF(recurring_stockout_locations = 216, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 26, 'Historical unfulfilled units',
        IF(historical_unfulfilled_units = 36424, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 27, 'Historical stockout location-months',
        IF(historical_stockout_location_months = 815, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 28, 'Historical potential gross margin',
        IF(
            ABS(
                historical_margin_exposure_inr - 33058084.60
            ) < 0.01,
            0, 1
        )
    FROM audit_metrics

    UNION ALL SELECT 29, 'Preserved unknown on-time outcomes',
        IF(unknown_ontime_records = 7, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 30, 'Preserved missing lead times with deliveries',
        IF(missing_lead_time_with_deliveries = 15, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 31, 'October inventory records',
        IF(october_records = 360, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 32, 'October demand',
        IF(october_demand = 51603, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 33, 'October fulfilled units',
        IF(october_fulfilled = 47922, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 34, 'October unfulfilled units',
        IF(october_unfulfilled = 3681, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 35, 'October zero-stock locations',
        IF(october_zero_stock = 79, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 36, 'October below-reorder locations',
        IF(october_below_reorder = 141, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 37, 'October healthy locations',
        IF(october_healthy = 140, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 38, 'October stockout locations',
        IF(october_stockout_locations = 79, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 39, 'October stockout days',
        IF(october_stockout_days = 751, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 40, 'October reorder gap',
        IF(october_reorder_gap = 4544, 0, 1)
    FROM audit_metrics

    UNION ALL SELECT 41, 'October potential unmet sales',
        IF(
            ABS(october_unmet_sales - 9356605.50) < 0.01,
            0, 1
        )
    FROM audit_metrics

    UNION ALL SELECT 42, 'October associated unmet product cost',
        IF(
            ABS(october_unmet_cost - 6285399.67) < 0.01,
            0, 1
        )
    FROM audit_metrics

    UNION ALL SELECT 43, 'October potential gross margin',
        IF(
            ABS(october_margin_exposure - 3071205.83) < 0.01,
            0, 1
        )
    FROM audit_metrics

    UNION ALL SELECT 44, 'October sales-cost-margin bridge',
        IF(
            ABS(
                october_unmet_sales
                - october_unmet_cost
                - october_margin_exposure
            ) < 0.01,
            0, 1
        )
    FROM audit_metrics
),

-- =============================================================
-- STEP 10: QA SUMMARY
-- =============================================================

qa_summary AS (

    SELECT
        COUNT(*) AS rules_executed,

        COALESCE(SUM(failed), 0)
            AS failed_rules,

        COALESCE(
            GROUP_CONCAT(
                CASE
                    WHEN failed = 1 THEN rule_name
                END
                ORDER BY id
                SEPARATOR '; '
            ),
            'None'
        ) AS failed_rule_names

    FROM validation_rules
),

-- =============================================================
-- STEP 11: FINAL VERTICAL SCORECARD
-- =============================================================

report AS (

    SELECT 1 AS seq, 'Inventory Rows' AS metric,
        CAST(inventory_rows AS CHAR) AS value
    FROM audit_metrics

    UNION ALL SELECT 2, 'Supplier Rows',
        CAST(supplier_rows AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 3, 'Unique Inventory Business Keys',
        CAST(unique_inventory_keys AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 4, 'Unique Supplier IDs',
        CAST(unique_supplier_ids AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 5, 'Distinct SKUs',
        CAST(distinct_skus AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 6, 'Distinct Warehouses',
        CAST(distinct_warehouses AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 7, 'Reporting Months',
        CAST(distinct_months AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 8, 'First Reporting Month',
        CAST(first_month AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 9, 'Last Reporting Month',
        CAST(last_month AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 10, 'SKU-Warehouse Locations',
        CAST(distinct_locations AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 11, 'Duplicate Business-Grain Rows',
        CAST(duplicate_grain_rows AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 12, 'Incomplete Reporting Months',
        CAST(incomplete_reporting_months AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 13, 'Missing Required Inventory Keys',
        CAST(missing_key_records AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 14, 'Inventory Balance Errors',
        CAST(inventory_balance_errors AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 15, 'Unmatched Supplier Records',
        CAST(unmatched_supplier_records AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 16, 'Unknown On-Time Outcome Records',
        CAST(unknown_ontime_records AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 17, 'Missing Lead Times With Deliveries',
        CAST(missing_lead_time_with_deliveries AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 18, 'Incomplete Location Histories',
        CAST(incomplete_location_histories AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 19, 'Recurring Stockout Locations',
        CAST(recurring_stockout_locations AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 20, 'Historical Unfulfilled Units',
        CAST(historical_unfulfilled_units AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 21, 'Historical Stockout Location-Months',
        CAST(historical_stockout_location_months AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 22, 'Historical Potential Margin (INR)',
        CAST(
            ROUND(historical_margin_exposure_inr, 2)
            AS CHAR
        )
    FROM audit_metrics

    UNION ALL SELECT 23, 'October Demand Units',
        CAST(october_demand AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 24, 'October Fulfilled Units',
        CAST(october_fulfilled AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 25, 'October Unfulfilled Units',
        CAST(october_unfulfilled AS CHAR)
    FROM audit_metrics

    UNION ALL SELECT 26, 'October Potential Margin (INR)',
        CAST(
            ROUND(october_margin_exposure, 2)
            AS CHAR
        )
    FROM audit_metrics

    UNION ALL SELECT 27, 'SQL QA Rules Executed',
        CAST(rules_executed AS CHAR)
    FROM qa_summary

    UNION ALL SELECT 28, 'Failed SQL QA Rules',
        CAST(failed_rules AS CHAR)
    FROM qa_summary

    UNION ALL SELECT 29, 'Failed Rule Names',
        failed_rule_names
    FROM qa_summary

    UNION ALL SELECT 30, 'Overall Database Integrity Status',

        CASE
            WHEN rules_executed = 44
             AND failed_rules = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END

    FROM qa_summary
)

SELECT
    metric,
    value

FROM report

ORDER BY seq;
-- =========================================================
-- SECTION 09.1: VERIFIED DATABASE INTEGRITY
--               & FINAL SQL BASELINE
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- DATABASE:
-- supply_chain_ai_db
--
-- SOURCE TABLES:
-- inventory
-- suppliers
--
-- STATUS:
-- VERIFIED - PASS
--
-- SQL QA Rules Executed   : 44
-- SQL QA Rules Passed     : 44
-- SQL QA Rules Failed     : 0
-- Failed Rule Names       : None
--
-- Output Format:
-- 30 metric/value rows
--
-- =========================================================
-- A. DATASET STRUCTURE
-- =========================================================
--
-- Inventory Records             : 4320
-- Supplier Records              : 12
--
-- Unique Inventory Business Keys: 4320
-- Unique Supplier IDs           : 12
--
-- Distinct SKUs                 : 120
-- Distinct Warehouses           : 3
-- Reporting Months              : 12
-- SKU-Warehouse Locations       : 360
--
-- First Reporting Month         : 2025-11-01
-- Last Reporting Month          : 2026-10-01
--
-- Expected Inventory Structure:
-- 120 SKUs x 3 Warehouses x 12 Months
-- = 4320 records
--
-- Reconciliation: PASS
--
-- =========================================================
-- B. BUSINESS KEY VALIDATION
-- =========================================================
--
-- Unique Inventory Grain:
-- sku_id + warehouse + reporting_month
--
-- Unique Business Keys          : 4320
-- Duplicate Grain Rows          : 0
--
-- Missing Required Keys         : 0
-- Incomplete Reporting Months   : 0
-- Incomplete Location Histories : 0
--
-- IMPORTANT:
-- The inventory table does not require
-- a separate inventory_id column.
--
-- Uniqueness is validated using the
-- actual three-column business key.
--
-- Business Grain Validation: PASS
--
-- =========================================================
-- C. INVENTORY INTEGRITY
-- =========================================================
--
-- Inventory Balance Errors      : 0
-- Unmatched Supplier Records    : 0
--
-- Inventory Balance Equation:
--
-- Opening Stock
-- + Received Units
-- - Fulfilled Units
-- = Closing Stock
--
-- All inventory integrity checks
-- returned PASS.
--
-- =========================================================
-- D. DOCUMENTED MISSING OBSERVATIONS
-- =========================================================
--
-- Unknown On-Time Outcomes:
-- 7 records
--
-- Missing Observed Lead Times
-- With Recorded Deliveries:
-- 15 records
--
-- IMPORTANT:
-- These unknown values are intentionally
-- preserved as NULL.
--
-- An unknown on-time outcome must not
-- automatically be treated as a late
-- or an on-time delivery.
--
-- Missing observed lead times must not
-- automatically be treated as zero days.
--
-- Both exception counts reconcile with
-- the previously documented cleaning audit.
--
-- =========================================================
-- E. HISTORICAL INVENTORY RISK
-- =========================================================
--
-- Reporting Period:
-- November 2025 - October 2026
--
-- Historical Unfulfilled Units:
-- 36424
--
-- Historical Stockout Location-Months:
-- 815
--
-- Recurring Stockout Locations:
-- 216
--
-- Complete SKU-Warehouse Locations:
-- 360
--
-- Recurrence Rate:
-- 216 / 360 x 100 = 60.00%
--
-- Recurring Stockout Definition:
-- A location with stockout_days > 0
-- in at least two reporting months.
--
-- Historical Potential Gross-Margin Exposure:
-- INR 33058084.60
--
-- Historical Reconciliation: PASS
--
-- =========================================================
-- F. OCTOBER 2026 BUSINESS BENCHMARKS
-- =========================================================
--
-- Total Demand Units:
-- 51603
--
-- Total Fulfilled Units:
-- 47922
--
-- Total Unfulfilled Units:
-- 3681
--
-- Demand Balance:
-- 51603 - 47922 = 3681
--
-- October Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- Formula:
--
-- SUM(
--   (demand_units - fulfilled_units)
--   * GREATEST(
--       unit_selling_price - unit_cost,
--       0
--     )
-- )
--
-- October Financial Reconciliation: PASS
--
-- =========================================================
-- G. VALIDATION COVERAGE
-- =========================================================
--
-- The 44 SQL rules cover:
--
-- 1. Table record counts
-- 2. Composite business-key uniqueness
-- 3. Supplier-master uniqueness
-- 4. Reporting-period coverage
-- 5. Duplicate monthly inventory records
-- 6. Missing required identifiers
-- 7. Missing required numerical fields
-- 8. Inventory balance integrity
-- 9. Nonnegative quantities
-- 10. Fulfillment constraints
-- 11. Valid unit costs and selling prices
-- 12. Supplier delivery-count integrity
-- 13. Stockout-day validity
-- 14. Supplier relationship integrity
-- 15. Historical location completeness
-- 16. Stockout recurrence
-- 17. Preserved missing observations
-- 18. Historical financial benchmarks
-- 19. October operational benchmarks
-- 20. October financial bridge
--
-- Total Rules Executed:
-- 44
--
-- Total Failed Rules:
-- 0
--
-- Overall Database Integrity:
-- PASS
--
-- =========================================================
-- H. BUSINESS CONCLUSION
-- =========================================================
--
-- The MySQL inventory and supplier tables
-- passed all 44 database-level checks.
--
-- The data contains the expected records,
-- business-key structure, historical periods,
-- financial values and documented exceptions.
--
-- These findings support proceeding to
-- an independent source reconciliation.
--
-- =========================================================
-- I. IMPORTANT LIMITATION
-- =========================================================
--
-- This section validates the MySQL database.
--
-- It does NOT independently prove that
-- all imported records and values match
-- inventory_clean.csv and suppliers_clean.csv.
--
-- A database may be internally consistent
-- even if source records were changed or
-- omitted during the import process.
--
-- Therefore, source-to-database comparison
-- remains mandatory before final sign-off.
--
-- =========================================================
-- SECTION 09.1 STATUS:
-- VERIFIED - 44/44 PASS
--
-- NEXT:
-- SECTION 09.2 - INDEPENDENT CSV-TO-MYSQL
--                ROW AND COLUMN RECONCILIATION
-- =========================================================
-- =========================================================
-- SECTION 09.2: INDEPENDENT CSV-TO-MYSQL RECONCILIATION
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- VALIDATION STATUS:
-- VERIFIED - PASS
--
-- =========================================================
-- A. RECONCILIATION OBJECTIVE
-- =========================================================
--
-- Verify that cleaned Python source datasets
-- match their corresponding MySQL table exports.
--
-- This is an independent source comparison,
-- not merely another database-level QA query.
--
-- =========================================================
-- B. RECONCILIATION INPUTS
-- =========================================================
--
-- CLEANED SOURCE DATASETS:
--
-- inventory_clean.csv
-- suppliers_clean.csv
--
-- MYSQL TABLE EXPORTS:
--
-- inventory_db_export.csv
-- suppliers_db_export.csv
--
-- RECONCILIATION PROGRAM:
--
-- 09_reconcile_csv_mysql.py
--
-- =========================================================
-- C. VERIFIED INVENTORY RECONCILIATION
-- =========================================================
--
-- Clean Inventory Rows          : 4320
-- MySQL Inventory Rows          : 4320
--
-- Missing Database Records      : 0
-- Extra Database Records        : 0
-- Cell-Value Mismatches         : 0
--
-- Comparison Business Key:
-- sku_id + warehouse + reporting_month
--
-- INVENTORY RECONCILIATION: PASS
--
-- =========================================================
-- D. VERIFIED SUPPLIER RECONCILIATION
-- =========================================================
--
-- Clean Supplier Rows           : 12
-- MySQL Supplier Rows           : 12
--
-- Missing Database Records      : 0
-- Extra Database Records        : 0
-- Cell-Value Mismatches         : 0
--
-- Comparison Business Key:
-- supplier_id
--
-- SUPPLIER RECONCILIATION: PASS
--
-- =========================================================
-- E. VALIDATION COVERAGE
-- =========================================================
--
-- 1. Source and database record counts
-- 2. Business-key alignment
-- 3. Missing source/database records
-- 4. Unexpected database records
-- 5. Column-level value comparison
-- 6. Date representation normalization
-- 7. Numeric representation normalization
-- 8. NULL/missing-value handling
-- 9. Financial benchmark consistency
-- 10. Overall source-to-database status
--
-- =========================================================
-- F. GENERATED AUDIT EVIDENCE
-- =========================================================
--
-- OUTPUT FOLDER:
-- reconciliation_09/
--
-- RESULTS FILE:
-- 09_reconciliation_results.json
--
-- MISMATCH REPORT:
-- 09_mismatch_details.csv
--
-- FINAL PROGRAM OUTPUT:
--
-- Inventory: PASS
-- Suppliers: PASS
--
-- OVERALL SOURCE-TO-DATABASE RESULT:
-- PASS
--
-- =========================================================
-- G. BUSINESS INTERPRETATION
-- =========================================================
--
-- Both cleaned source datasets successfully
-- reconciled with their exported MySQL tables.
--
-- No missing records, unexpected records,
-- or cell-value discrepancies were reported.
--
-- This provides evidence that the imported
-- datasets retained their cleaned values.
--
-- Together with the 44/44 database-integrity
-- checks from Section 09.1, this supports
-- the final data handoff review.
--
-- =========================================================
-- H. LIMITATIONS
-- =========================================================
--
-- 1. Comparison uses database CSV exports.
--
-- 2. Results apply to the database state
--    represented by those exports.
--
-- 3. Formatting-equivalent numeric and date
--    values may be normalized before comparison.
--
-- 4. A PASS result does not establish that
--    synthetic business assumptions are real.
--
-- 5. Final source-to-dashboard readiness
--    requires Section 09.3 sign-off.
--
-- =========================================================
-- SECTION 09.2 STATUS:
-- VERIFIED - PASS
--
-- NEXT:
-- SECTION 09.3 - FINAL RECONCILIATION SIGN-OFF
-- =========================================================
-- =========================================================
-- SECTION 09.3: FINAL RECONCILIATION SIGN-OFF
--               & POWER BI DATA HANDOFF
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- SIGN-OFF DATE:
-- 2026-11-05
--
-- DATABASE:
-- supply_chain_ai_db
--
-- TECHNICAL SIGN-OFF STATUS:
-- PASS
--
-- =========================================================
-- A. RECONCILED SOURCE TABLES
-- =========================================================
--
-- TABLE 1: inventory
--
-- Clean Source Records: 4320
-- MySQL Export Records: 4320
-- Missing Records: 0
-- Extra Records: 0
-- Cell Mismatches: 0
-- Result: PASS
--
-- Business Grain:
-- sku_id + warehouse + reporting_month
--
-- TABLE 2: suppliers
--
-- Clean Source Records: 12
-- MySQL Export Records: 12
-- Missing Records: 0
-- Extra Records: 0
-- Cell Mismatches: 0
-- Result: PASS
--
-- Business Key:
-- supplier_id
--
-- TOTAL RECONCILED RECORDS:
-- 4332
--
-- SOURCE-TO-DATABASE RESULT:
-- PASS
--
-- =========================================================
-- B. DATABASE INTEGRITY SIGN-OFF
-- =========================================================
--
-- Final Database QA Rules: 44
-- Passed: 44
-- Failed: 0
--
-- Unique Inventory Business Keys: 4320
-- Distinct SKUs: 120
-- Warehouses: 3
-- Reporting Months: 12
-- Distinct Suppliers: 12
--
-- Duplicate Business-Grain Rows: 0
-- Incomplete Reporting Months: 0
-- Missing Required Inventory Keys: 0
-- Inventory Balance Errors: 0
-- Unmatched Supplier Records: 0
-- Incomplete Location Histories: 0
--
-- DATABASE INTEGRITY RESULT:
-- PASS
--
-- =========================================================
-- C. PRESERVED DATA-QUALITY LIMITATIONS
-- =========================================================
--
-- Unknown On-Time Outcome Records: 7
--
-- Missing Observed Lead Times
-- With Recorded Deliveries: 15
--
-- These observations remain NULL.
--
-- Unknown delivery outcomes must not
-- automatically count as successful
-- or unsuccessful deliveries.
--
-- Missing observed lead times must
-- not automatically become zero days.
--
-- Both exceptions are documented and
-- must remain visible in downstream
-- business analysis.
--
-- =========================================================
-- D. VERIFIED BUSINESS BENCHMARKS
-- =========================================================
--
-- HISTORICAL PERIOD:
-- November 2025 - October 2026
--
-- Historical Unfulfilled Units:
-- 36424
--
-- Historical Stockout Location-Months:
-- 815
--
-- Recurring Stockout Locations:
-- 216 of 360
--
-- Historical Potential Margin Exposure:
-- INR 33058084.60
--
-- ---------------------------------------------------------
--
-- OCTOBER 2026:
--
-- Demand Units:
-- 51603
--
-- Fulfilled Units:
-- 47922
--
-- Unfulfilled Units:
-- 3681
--
-- Fill Rate:
-- 92.87%
--
-- Zero-Stock Locations:
-- 79
--
-- Below-Reorder Locations:
-- 141
--
-- Healthy Locations:
-- 140
--
-- Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- Financial QA Rules:
-- 48 of 48 PASS
--
-- =========================================================
-- E. ANALYTICAL OUTPUTS VERIFIED
-- =========================================================
--
-- 01. Database tables and relationships:
-- VERIFIED
--
-- 02. Import quality and validation:
-- VERIFIED
--
-- 03. October business KPIs:
-- VERIFIED
--
-- 04. Monthly historical trends:
-- VERIFIED
--
-- 05. Warehouse performance:
-- VERIFIED
--
-- 06. Supplier performance:
-- 31/31 QA PASS
--
-- 07. Inventory risk analysis:
-- 44/44 QA PASS
--
-- 08. Financial exposure:
-- 48/48 QA PASS
--
-- 09. Database reconciliation:
-- 44/44 QA PASS
--
-- 09.2 Source-to-database reconciliation:
-- INVENTORY PASS
-- SUPPLIERS PASS
--
-- =========================================================
-- F. RECONCILIATION EVIDENCE
-- =========================================================
--
-- PYTHON AUDIT:
-- 09_reconcile_csv_mysql.py
--
-- REPORT FOLDER:
-- reconciliation_09/
--
-- JSON AUDIT:
-- 09_reconciliation_results.json
--
-- DIFFERENCE REPORT:
-- 09_mismatch_details.csv
--
-- The program reported zero missing
-- records, extra records or cell mismatches.
--
-- Note:
-- Source comparison validates the MySQL
-- state represented by the exported CSVs.
--
-- =========================================================
-- G. POWER BI HANDOFF SPECIFICATION
-- =========================================================
--
-- DATABASE:
-- supply_chain_ai_db
--
-- RECOMMENDED SOURCE TABLES:
-- inventory
-- suppliers
--
-- CONNECTION MODE:
-- Import
--
-- DO NOT USE AS DASHBOARD DATA:
-- Raw uncleaned CSV datasets
-- Cleaning change logs
-- Temporary database export CSVs
-- Reconciliation mismatch reports
--
-- RELATIONSHIP:
--
-- suppliers[supplier_id] = ONE side
-- inventory[supplier_id] = MANY side
--
-- Recommended Filter Direction:
-- Single direction, suppliers to inventory
--
-- Reporting Date Field:
-- inventory[reporting_month]
--
-- A Date Dimension will be created
-- during Power BI modeling.
--
-- BUSINESS GRAIN:
-- One SKU x Warehouse x Reporting Month
--
-- =========================================================
-- H. POWER BI ANALYSIS SCOPE
-- =========================================================
--
-- Planned Report Pages:
--
-- PAGE 1:
-- Supply Chain Performance & Trends
--
-- PAGE 2:
-- Inventory Risk & Financial Decisions
--
-- Required Interactive Features:
--
-- 1. Slicer-driven cross-filtering
-- 2. Field Parameters for metric switching
-- 3. Hierarchy drill-down
-- 4. Conditional KPI colors/status
-- 5. Demand-growth what-if slider
--
-- Required Analysis:
--
-- Fill Rate
-- Stockout Rate
-- At-Risk Inventory
-- Supplier On-Time Delivery
-- Inventory Turnover
-- Warehouse Comparisons
-- Historical Trends
-- Supplier Comparisons
-- SKU-Level Inventory Risk
-- Potential Financial Exposure
-- Recovery Scenario Analysis
--
-- =========================================================
-- I. DEFINITIONS & LIMITATIONS
-- =========================================================
--
-- 1. All business data is synthetic.
--
-- 2. Potential margin exposure is not
--    realized accounting profit or loss.
--
-- 3. Recovery scenarios are illustrative
--    assumptions, not forecasts.
--
-- 4. Supplier association does not prove
--    supplier-caused inventory shortages.
--
-- 5. Known missing observations must
--    be handled explicitly in DAX.
--
-- 6. Historical and October measures
--    must preserve their intended
--    filter context and business grain.
--
-- 7. The source-to-database comparison
--    reflects database exports at the
--    time the audit was run.
--
-- 8. Changes to source data or database
--    tables require renewed validation.
--
-- 9. Technical QA completion is not
--    stakeholder or production approval.
--
-- =========================================================
-- J. FINAL TECHNICAL DECISION
-- =========================================================
--
-- Database Integrity:
-- PASS
--
-- Source-to-Database Reconciliation:
-- PASS
--
-- Financial Reconciliation:
-- PASS
--
-- Data Quality Exceptions:
-- DOCUMENTED
--
-- SQL ANALYSIS STATUS:
-- COMPLETE
--
-- POWER BI DATA HANDOFF:
-- READY
--
-- =========================================================
-- PHASE 2 FINAL STATUS:
-- COMPLETE - TECHNICAL QA PASSED
--
-- NEXT PHASE:
-- PHASE 3 - POWER BI DATA MODELING
--           & INTERACTIVE DASHBOARD
-- =========================================================