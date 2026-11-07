USE supply_chain_ai_db;

-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 02: DATA IMPORT & INTEGRITY VALIDATION
-- Purpose: Validate cleaned supplier and inventory data
-- before performing business KPI calculations.


-- A. ROW COUNTS AND DISTINCT IDENTIFIERS

SELECT 'Supplier Rows' AS metric,
       COUNT(*) AS value
FROM suppliers

UNION ALL

SELECT 'Unique Supplier IDs',
       COUNT(DISTINCT supplier_id)
FROM suppliers

UNION ALL

SELECT 'Inventory Rows',
       COUNT(*)
FROM inventory

UNION ALL

SELECT 'Unique Inventory IDs',
       COUNT(DISTINCT inventory_record_id)
FROM inventory

UNION ALL

SELECT 'Distinct SKUs',
       COUNT(DISTINCT sku_id)
FROM inventory

UNION ALL

SELECT 'Warehouses',
       COUNT(DISTINCT warehouse)
FROM inventory

UNION ALL

SELECT 'Reporting Months',
       COUNT(DISTINCT reporting_month)
FROM inventory

-- B. RELATIONSHIP VALIDATION

UNION ALL

SELECT 'Unmatched Supplier IDs',
       COUNT(*)
FROM inventory i
LEFT JOIN suppliers s
    ON i.supplier_id = s.supplier_id
WHERE s.supplier_id IS NULL

-- C. INVENTORY BALANCE VALIDATION

UNION ALL

SELECT 'Inventory Balance Errors',
       COUNT(*)
FROM inventory
WHERE opening_stock_units
      + received_units
      - fulfilled_units <> closing_stock_units

-- D. MISSING VALUE TREATMENTS

UNION ALL

SELECT 'Unknown Supplier Regions',
       COUNT(*)
FROM suppliers
WHERE supplier_region = 'Unknown'

UNION ALL

SELECT 'Unknown On-Time Outcomes',
       COUNT(*)
FROM inventory
WHERE supplier_on_time_deliveries_count IS NULL

UNION ALL

SELECT 'Missing Lead Times With Deliveries',
       COUNT(*)
FROM inventory
WHERE replenishment_lead_time_days IS NULL
  AND supplier_deliveries_count > 0;