-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- DATABASE INITIALIZATION
-- Creates the database if it does not already exist.

CREATE DATABASE IF NOT EXISTS supply_chain_ai_db;

USE supply_chain_ai_db;

-- TABLE 1: SUPPLIERS
CREATE TABLE IF NOT EXISTS suppliers (

    supplier_id VARCHAR(12) PRIMARY KEY,
    supplier_name VARCHAR(80) NOT NULL,
    supplier_region VARCHAR(20) NOT NULL,
    supplier_category VARCHAR(50) NOT NULL,

    contracted_lead_time_days INT NOT NULL,
    contractual_on_time_target DECIMAL(6,4) NOT NULL,
    supplier_status VARCHAR(20) NOT NULL,

    CONSTRAINT chk_sup_lead
        CHECK (contracted_lead_time_days > 0),

    CONSTRAINT chk_sup_target
        CHECK (contractual_on_time_target BETWEEN 0 AND 1)
);


-- TABLE 2: INVENTORY
CREATE TABLE IF NOT EXISTS inventory (

    inventory_record_id VARCHAR(12) PRIMARY KEY,
    reporting_month DATE NOT NULL,

    sku_id VARCHAR(12) NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    warehouse VARCHAR(20) NOT NULL,
    supplier_id VARCHAR(12) NOT NULL,

    opening_stock_units INT NOT NULL,
    received_units INT NOT NULL,
    demand_units INT NOT NULL,
    fulfilled_units INT NOT NULL,
    closing_stock_units INT NOT NULL,
    reorder_point_units INT NOT NULL,

    unit_cost DECIMAL(12,2) NOT NULL,
    unit_selling_price DECIMAL(12,2) NOT NULL,

    stockout_days INT NOT NULL,
    replenishment_lead_time_days DECIMAL(8,2) NULL,

    supplier_deliveries_count INT NOT NULL,
    supplier_on_time_deliveries_count INT NULL,

    -- Calculated analytical columns
    days_in_month INT NOT NULL,
    unfulfilled_units INT NOT NULL,
    fulfilled_cogs_proxy DECIMAL(16,2) NOT NULL,
    closing_inventory_value DECIMAL(16,2) NOT NULL,
    potential_margin_exposure DECIMAL(16,2) NOT NULL,
    days_inventory_coverage DECIMAL(14,4) NULL,
    inventory_status VARCHAR(32) NOT NULL,
    excess_stock_value_proxy DECIMAL(16,2) NOT NULL,

    -- Relationship
    CONSTRAINT fk_inventory_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id),

    -- Prevent duplicate SKU-warehouse-month records
    CONSTRAINT uq_inventory_grain
        UNIQUE (reporting_month, sku_id, warehouse),

    -- Inventory accounting validation
    CONSTRAINT chk_inventory_balance
        CHECK (
            opening_stock_units
            + received_units
            - fulfilled_units
            = closing_stock_units
        ),

    CONSTRAINT chk_fulfilled_demand
        CHECK (fulfilled_units <= demand_units),

    CONSTRAINT chk_ontime
        CHECK (
            supplier_on_time_deliveries_count IS NULL
            OR (
                supplier_on_time_deliveries_count >= 0
                AND supplier_on_time_deliveries_count
                    <= supplier_deliveries_count
            )
        )
);


-- VERIFY BOTH TABLES
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'supply_chain_ai_db'
ORDER BY table_name;