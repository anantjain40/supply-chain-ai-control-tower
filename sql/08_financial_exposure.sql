-- =========================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 08: FINANCIAL EXPOSURE ANALYSIS
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
-- Translate unmet demand and inventory shortages
-- into estimated financial exposure, identify
-- concentration, evaluate scenarios and support
-- financially prioritized business decisions.
--
-- SCRIPT SECTIONS:
-- 08.1 Financial Impact Bridge
-- 08.2 Financial Concentration
-- 08.3 Recovery Scenario Analysis
-- 08.4 Business Recommendations
-- 08.5 Final Financial QA
--
-- IMPORTANT DEFINITIONS:
--
-- Potential sales value is not confirmed
-- lost revenue.
--
-- Potential gross-margin exposure is not
-- confirmed lost profit.
--
-- Recovery scenarios are assumptions,
-- not validated forecasts.
--
-- =========================================================
-- SECTION 08.1: OCTOBER FINANCIAL IMPACT BRIDGE
-- =========================================================
--
-- BUSINESS QUESTIONS:
-- 1. How much customer demand went unfulfilled?
-- 2. What is its estimated selling value?
-- 3. What product cost is associated with it?
-- 4. What is the potential gross-margin exposure?
-- 5. Do the financial components reconcile?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- PERIOD:
-- October 2026
--
-- EXPECTED OUTPUT:
-- Vertical metric | value scorecard
--
-- =========================================================


WITH october_financial_lines AS (

    SELECT

        demand_units,

        fulfilled_units,

        stockout_days,

        unit_selling_price,

        unit_cost,

        -- Unfulfilled customer demand
        demand_units - fulfilled_units
            AS unfulfilled_units,

        -- Potential selling value of unmet demand
        (demand_units - fulfilled_units)
        * unit_selling_price
            AS potential_sales_value_inr,

        -- Associated product cost of unmet demand
        (demand_units - fulfilled_units)
        * unit_cost
            AS associated_product_cost_inr,

        -- Signed potential gross contribution
        (demand_units - fulfilled_units)
        * (unit_selling_price - unit_cost)
            AS signed_potential_margin_inr,

        -- Previously approved nonnegative
        -- potential gross-margin exposure formula
        (demand_units - fulfilled_units)
        * GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS potential_margin_exposure_inr,

        -- Modeled selling value of fulfilled units
        fulfilled_units * unit_selling_price
            AS fulfilled_sales_value_inr,

        -- Modeled product cost of fulfilled units
        fulfilled_units * unit_cost
            AS fulfilled_product_cost_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

-- =========================================================
-- STEP 2: CALCULATE OCTOBER PORTFOLIO TOTALS
-- =========================================================

october_financial_totals AS (

    SELECT

        COUNT(*) AS inventory_locations,

        SUM(
            CASE
                WHEN unfulfilled_units > 0
                THEN 1 ELSE 0
            END
        ) AS locations_with_unmet_demand,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        SUM(unfulfilled_units)
            AS total_unfulfilled_units,

        SUM(potential_sales_value_inr)
            AS total_potential_sales_value,

        SUM(associated_product_cost_inr)
            AS total_associated_product_cost,

        SUM(signed_potential_margin_inr)
            AS total_signed_potential_margin,

        SUM(potential_margin_exposure_inr)
            AS total_potential_margin_exposure,

        SUM(fulfilled_sales_value_inr)
            AS total_fulfilled_sales_value,

        SUM(fulfilled_product_cost_inr)
            AS total_fulfilled_product_cost

    FROM october_financial_lines

),

-- =========================================================
-- STEP 3: BUILD VERTICAL FINANCIAL SCORECARD
-- =========================================================

financial_report AS (

    SELECT
        1 AS seq,
        'Reporting Month' AS metric,
        '2026-10' AS value

    UNION ALL

    SELECT 2, 'Inventory Locations',
        CAST(inventory_locations AS CHAR)
    FROM october_financial_totals

    UNION ALL

    SELECT 3, 'Locations With Unmet Demand',
        CAST(locations_with_unmet_demand AS CHAR)
    FROM october_financial_totals

    UNION ALL

    SELECT 4, 'Locations With Recorded Stockouts',
        CAST(stockout_locations AS CHAR)
    FROM october_financial_totals

    UNION ALL

    SELECT 5, 'Total Demand Units',
        CAST(total_demand_units AS CHAR)
    FROM october_financial_totals

    UNION ALL

    SELECT 6, 'Total Fulfilled Units',
        CAST(total_fulfilled_units AS CHAR)
    FROM october_financial_totals

    UNION ALL

    SELECT 7, 'Total Unfulfilled Units',
        CAST(total_unfulfilled_units AS CHAR)
    FROM october_financial_totals

    UNION ALL

    SELECT 8, 'Fill Rate (%)',
        CAST(
            ROUND(
                total_fulfilled_units * 100.0 /
                NULLIF(total_demand_units, 0),
                2
            ) AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 9, 'Unfulfilled Demand Rate (%)',
        CAST(
            ROUND(
                total_unfulfilled_units * 100.0 /
                NULLIF(total_demand_units, 0),
                2
            ) AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 10, 'Potential Sales Value of Unmet Demand (INR)',
        CAST(
            ROUND(total_potential_sales_value, 2)
            AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 11, 'Associated Product Cost of Unmet Demand (INR)',
        CAST(
            ROUND(total_associated_product_cost, 2)
            AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 12, 'Signed Potential Gross Margin (INR)',
        CAST(
            ROUND(total_signed_potential_margin, 2)
            AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 13, 'Potential Gross-Margin Exposure (INR)',
        CAST(
            ROUND(total_potential_margin_exposure, 2)
            AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 14, 'Potential Margin Per Unfulfilled Unit (INR)',
        CAST(
            ROUND(
                total_potential_margin_exposure /
                NULLIF(total_unfulfilled_units, 0),
                2
            ) AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 15, 'Potential Margin Rate on Unmet Sales (%)',
        CAST(
            ROUND(
                total_potential_margin_exposure * 100.0 /
                NULLIF(total_potential_sales_value, 0),
                2
            ) AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 16, 'Modeled Fulfilled Sales Value (INR)',
        CAST(
            ROUND(total_fulfilled_sales_value, 2)
            AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 17, 'Modeled Fulfilled Product Cost (INR)',
        CAST(
            ROUND(total_fulfilled_product_cost, 2)
            AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 18, 'Modeled Fulfilled Gross Contribution (INR)',
        CAST(
            ROUND(
                total_fulfilled_sales_value
                - total_fulfilled_product_cost,
                2
            ) AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 19, 'Margin Bridge Difference (INR)',
        CAST(
            ROUND(
                total_potential_margin_exposure
                - (
                    total_potential_sales_value
                    - total_associated_product_cost
                ),
                2
            ) AS CHAR
        )
    FROM october_financial_totals

    UNION ALL

    SELECT 20, 'October Financial Reconciliation Status',

        CASE
            WHEN inventory_locations = 360

             AND locations_with_unmet_demand = 79

             AND stockout_locations = 79

             AND total_demand_units = 51603

             AND total_fulfilled_units = 47922

             AND total_unfulfilled_units = 3681

             AND ABS(
                 total_potential_sales_value
                 - 9356605.50
             ) < 0.01

             AND ABS(
                 total_associated_product_cost
                 - 6285399.67
             ) < 0.01

             AND ABS(
                 total_potential_margin_exposure
                 - 3071205.83
             ) < 0.01

             AND ABS(
                 total_signed_potential_margin
                 - (
                     total_potential_sales_value
                     - total_associated_product_cost
                 )
             ) < 0.01

             AND ABS(
                 total_potential_margin_exposure
                 - total_signed_potential_margin
             ) < 0.01

            THEN 'PASS'

            ELSE 'REVIEW'

        END

    FROM october_financial_totals

)

-- =========================================================
-- FINAL OUTPUT: METRIC | VALUE
-- =========================================================

SELECT
    metric,
    value

FROM financial_report

ORDER BY seq;
-- =========================================================
-- SECTION 08.1: VERIFIED OCTOBER FINANCIAL IMPACT BRIDGE
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
-- 20 Metric Rows x 2 Columns
--
-- VALIDATION STATUS:
-- VERIFIED - PASS
--
-- =========================================================
-- A. OPERATIONAL BASELINE
-- =========================================================
--
-- Inventory Locations                 : 360
-- Locations With Unmet Demand         : 79
-- Locations With Stockouts            : 79
--
-- Total Demand Units                  : 51603
-- Total Fulfilled Units               : 47922
-- Total Unfulfilled Units             : 3681
--
-- Fill Rate                           : 92.87%
-- Unfulfilled Demand Rate             : 7.13%
--
-- Verification:
-- 51603 - 47922 = 3681 units
--
-- These results reconcile with the
-- verified October business KPI scorecard.
--
-- =========================================================
-- B. UNFULFILLED-DEMAND FINANCIAL BRIDGE
-- =========================================================
--
-- Potential Sales Value of Unmet Demand:
-- INR 9356605.50
--
-- Associated Product Cost of Unmet Demand:
-- INR 6285399.67
--
-- Signed Potential Gross Margin:
-- INR 3071205.83
--
-- Nonnegative Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- Financial Bridge:
-- 9356605.50 - 6285399.67
-- = 3071205.83
--
-- Financial Bridge Difference:
-- INR 0.00
--
-- FINANCIAL RECONCILIATION: PASS
--
-- =========================================================
-- C. UNIT-LEVEL FINANCIAL INTERPRETATION
-- =========================================================
--
-- Potential Margin Per Unfulfilled Unit:
-- INR 834.34
--
-- Formula:
-- 3071205.83 / 3681 = 834.34
--
-- Potential Margin Rate on Unmet Sales:
-- 32.82%
--
-- Formula:
-- 3071205.83 / 9356605.50 * 100
-- = 32.82%
--
-- IMPORTANT:
-- These are aggregated portfolio measures.
--
-- They are not identical to the margins
-- of every individual SKU.
--
-- =========================================================
-- D. MODELED FULFILLED BUSINESS
-- =========================================================
--
-- Modeled Fulfilled Sales Value:
-- INR 133883151.81
--
-- Modeled Fulfilled Product Cost:
-- INR 89019087.59
--
-- Modeled Fulfilled Gross Contribution:
-- INR 44864064.22
--
-- Reconciliation:
-- 133883151.81 - 89019087.59
-- = 44864064.22
--
-- INTERPRETATION:
-- These values estimate gross contribution
-- for fulfilled volume using recorded
-- unit selling prices and product costs.
--
-- They do not establish audited revenue
-- or recognized accounting profit.
--
-- =========================================================
-- E. FINANCIAL DEFINITIONS
-- =========================================================
--
-- UNFULFILLED UNITS:
-- demand_units - fulfilled_units
--
-- POTENTIAL SELLING VALUE:
-- unfulfilled_units * unit_selling_price
--
-- ASSOCIATED PRODUCT COST:
-- unfulfilled_units * unit_cost
--
-- SIGNED POTENTIAL GROSS MARGIN:
-- unfulfilled_units *
-- (unit_selling_price - unit_cost)
--
-- NONNEGATIVE POTENTIAL MARGIN EXPOSURE:
-- unfulfilled_units *
-- GREATEST(unit_selling_price - unit_cost, 0)
--
-- POTENTIAL MARGIN PER UNFULFILLED UNIT:
-- SUM(potential_margin_exposure)
-- / SUM(unfulfilled_units)
--
-- POTENTIAL MARGIN RATE:
-- SUM(potential_margin_exposure)
-- / SUM(potential_sales_value) * 100
--
-- =========================================================
-- F. FINANCIAL RECONCILIATION LOGIC
-- =========================================================
--
-- Checks performed within the SQL:
--
-- 1. October Inventory Locations = 360
-- 2. Unmet-Demand Locations = 79
-- 3. Stockout Locations = 79
-- 4. Total Demand Units = 51603
-- 5. Fulfilled Units = 47922
-- 6. Unfulfilled Units = 3681
-- 7. Potential Sales = INR 9356605.50
-- 8. Associated Product Cost = INR 6285399.67
-- 9. Potential Margin = INR 3071205.83
-- 10. Signed Margin Matches Sales-Cost Bridge
-- 11. Signed Margin Matches Nonnegative Exposure
--
-- Overall Combined Reconciliation Status:
-- PASS
--
-- Monetary comparisons use a tolerance
-- smaller than INR 0.01.
--
-- =========================================================
-- G. BUSINESS FINDINGS
-- =========================================================
--
-- 1. October fulfillment reached 92.87%.
--
-- 2. Total unmet demand was 3681 units
--    across 79 SKU-warehouse locations.
--
-- 3. The potential selling value associated
--    with those units was INR 9356605.50.
--
-- 4. The associated product cost was
--    INR 6285399.67.
--
-- 5. Potential gross-margin exposure was
--    INR 3071205.83.
--
-- 6. Potential margin per unfulfilled unit
--    averaged INR 834.34.
--
-- 7. The aggregate potential margin rate
--    on unmet sales was 32.82%.
--
-- 8. The fulfilled volume produced modeled
--    gross contribution of INR 44864064.22.
--
-- =========================================================
-- H. BUSINESS APPLICATION
-- =========================================================
--
-- Use potential gross-margin exposure
-- alongside actual shortage severity
-- and operational feasibility to identify
-- inventory investigation priorities.
--
-- Section 08.2 will investigate financial
-- concentration by warehouse, category
-- and supplier.
--
-- Section 08.3 will evaluate explicitly
-- assumed recovery scenarios.
--
-- No financial recovery has been demonstrated.
--
-- =========================================================
-- I. IMPORTANT LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business scenario.
--
-- 2. Potential unmet sales value is not
--    confirmed lost accounting revenue.
--
-- 3. Associated product cost represents
--    modeled cost of supplying unmet units.
--    It is not a booked financial loss.
--
-- 4. Potential gross-margin exposure is
--    not confirmed lost net profit.
--
-- 5. Actual recoverability depends on
--    customer demand, replenishment timing,
--    customer substitution and other factors.
--
-- 6. Fulfilled financial values are modeled
--    from units, prices and costs rather
--    than an audited accounting ledger.
--
-- 7. The signed and nonnegative margin
--    calculations agree for this dataset.
--    Their equality is not universal.
--
-- 8. The financial bridge does not include
--    all operating, logistics, financing
--    or incremental recovery costs.
--
-- =========================================================
-- SECTION 08.1 STATUS:
-- VERIFIED - PASS
--
-- NEXT:
-- SECTION 08.2 - FINANCIAL EXPOSURE CONCENTRATION
-- =========================================================
-- =========================================================
-- SECTION 08.2: FINANCIAL EXPOSURE CONCENTRATION
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
--
-- 1. Which warehouses contribute the most
--    potential gross-margin exposure?
--
-- 2. Which categories carry the greatest
--    financial impact of unfulfilled demand?
--
-- 3. Which supplier-associated portfolios
--    contribute the highest exposure?
--
-- 4. How do financial exposure and
--    shortage volume differ?
--
-- 5. How concentrated is financial exposure
--    within each business dimension?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- ANALYSIS GRAIN:
-- October SKU x Warehouse
--
-- GROUPING DIMENSIONS:
-- WAREHOUSE, CATEGORY, SUPPLIER
--
-- IMPORTANT:
-- Each dimension is a separate view of the
-- same company-wide financial exposure.
--
-- Do NOT add exposures across dimensions.
-- That would triple-count the portfolio.
--
-- =========================================================


WITH october_financial_base AS (

    SELECT

        sku_id,

        warehouse,

        category,

        supplier_id,

        demand_units,

        fulfilled_units,

        stockout_days,

        -- Unfulfilled customer demand
        demand_units - fulfilled_units
            AS unfulfilled_units,

        -- Estimated selling value of unmet units
        (
            demand_units - fulfilled_units
        ) * unit_selling_price
            AS potential_sales_value_inr,

        -- Estimated product cost of unmet units
        (
            demand_units - fulfilled_units
        ) * unit_cost
            AS associated_product_cost_inr,

        -- Potential nonnegative gross margin
        (
            demand_units - fulfilled_units
        ) * GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

-- =========================================================
-- STEP 2: AGGREGATE EACH BUSINESS DIMENSION
-- =========================================================

financial_segments AS (

    -- -----------------------------------------------------
    -- A. WAREHOUSE FINANCIAL EXPOSURE
    -- -----------------------------------------------------

    SELECT

        'WAREHOUSE' AS dimension_type,

        warehouse AS segment_name,

        COUNT(DISTINCT sku_id)
            AS distinct_skus,

        COUNT(*) AS inventory_locations,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(demand_units)
            AS demand_units,

        SUM(unfulfilled_units)
            AS unfulfilled_units,

        SUM(potential_sales_value_inr)
            AS potential_sales_value_inr,

        SUM(associated_product_cost_inr)
            AS associated_product_cost_inr,

        SUM(potential_margin_exposure_inr)
            AS potential_margin_exposure_inr

    FROM october_financial_base

    GROUP BY warehouse

    UNION ALL

    -- -----------------------------------------------------
    -- B. CATEGORY FINANCIAL EXPOSURE
    -- -----------------------------------------------------

    SELECT

        'CATEGORY' AS dimension_type,

        category AS segment_name,

        COUNT(DISTINCT sku_id)
            AS distinct_skus,

        COUNT(*) AS inventory_locations,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(demand_units)
            AS demand_units,

        SUM(unfulfilled_units)
            AS unfulfilled_units,

        SUM(potential_sales_value_inr)
            AS potential_sales_value_inr,

        SUM(associated_product_cost_inr)
            AS associated_product_cost_inr,

        SUM(potential_margin_exposure_inr)
            AS potential_margin_exposure_inr

    FROM october_financial_base

    GROUP BY category

    UNION ALL

    -- -----------------------------------------------------
    -- C. SUPPLIER-ASSOCIATED FINANCIAL EXPOSURE
    -- -----------------------------------------------------

    SELECT

        'SUPPLIER' AS dimension_type,

        supplier_id AS segment_name,

        COUNT(DISTINCT sku_id)
            AS distinct_skus,

        COUNT(*) AS inventory_locations,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        SUM(demand_units)
            AS demand_units,

        SUM(unfulfilled_units)
            AS unfulfilled_units,

        SUM(potential_sales_value_inr)
            AS potential_sales_value_inr,

        SUM(associated_product_cost_inr)
            AS associated_product_cost_inr,

        SUM(potential_margin_exposure_inr)
            AS potential_margin_exposure_inr

    FROM october_financial_base

    GROUP BY supplier_id

),

-- =========================================================
-- STEP 3: INDEPENDENT FINANCIAL RANKINGS
-- =========================================================

ranked_segments AS (

    SELECT

        financial_segments.*,

        -- Number of groups in each dimension
        COUNT(*) OVER (

            PARTITION BY dimension_type

        ) AS groups_in_dimension,

        -- Company totals within each dimension
        SUM(unfulfilled_units) OVER (

            PARTITION BY dimension_type

        ) AS portfolio_unfulfilled_units,

        SUM(potential_sales_value_inr) OVER (

            PARTITION BY dimension_type

        ) AS portfolio_potential_sales_inr,

        SUM(associated_product_cost_inr) OVER (

            PARTITION BY dimension_type

        ) AS portfolio_associated_cost_inr,

        SUM(potential_margin_exposure_inr) OVER (

            PARTITION BY dimension_type

        ) AS portfolio_margin_exposure_inr,

        -- Rank 1 = highest financial exposure
        DENSE_RANK() OVER (

            PARTITION BY dimension_type

            ORDER BY potential_margin_exposure_inr DESC

        ) AS financial_exposure_rank,

        -- Cumulative financial exposure by dimension
        SUM(potential_margin_exposure_inr) OVER (

            PARTITION BY dimension_type

            ORDER BY
                potential_margin_exposure_inr DESC,
                segment_name

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS cumulative_margin_exposure_inr

    FROM financial_segments

)

-- =========================================================
-- STEP 4: FINANCIAL CONCENTRATION SCORECARD
-- =========================================================

SELECT

    dimension_type,

    financial_exposure_rank,

    segment_name,

    distinct_skus,

    inventory_locations,

    stockout_locations,

    demand_units,

    unfulfilled_units,

    -- Unfulfilled demand rate within segment
    ROUND(
        unfulfilled_units * 100.0 /
        NULLIF(demand_units, 0),
        2
    ) AS unfulfilled_demand_rate_pct,

    ROUND(
        potential_sales_value_inr,
        2
    ) AS potential_unmet_sales_inr,

    ROUND(
        associated_product_cost_inr,
        2
    ) AS associated_unmet_cost_inr,

    ROUND(
        potential_margin_exposure_inr,
        2
    ) AS potential_margin_exposure_inr,

    -- Average potential margin per unmet unit
    ROUND(
        potential_margin_exposure_inr /
        NULLIF(unfulfilled_units, 0),
        2
    ) AS margin_per_unfulfilled_unit_inr,

    -- Share of total portfolio unmet demand
    ROUND(
        unfulfilled_units * 100.0 /
        NULLIF(portfolio_unfulfilled_units, 0),
        2
    ) AS unfulfilled_unit_share_pct,

    -- Share of company-wide potential margin
    ROUND(
        potential_margin_exposure_inr * 100.0 /
        NULLIF(portfolio_margin_exposure_inr, 0),
        2
    ) AS financial_exposure_share_pct,

    -- Cumulative financial share
    ROUND(
        cumulative_margin_exposure_inr * 100.0 /
        NULLIF(portfolio_margin_exposure_inr, 0),
        2
    ) AS cumulative_financial_share_pct,

    groups_in_dimension,

    -- Reconciliation benchmarks
    portfolio_unfulfilled_units,

    ROUND(
        portfolio_margin_exposure_inr,
        2
    ) AS portfolio_margin_exposure_inr,

    -- Independent reconciliation for each dimension
    CASE

        WHEN portfolio_unfulfilled_units = 3681

         AND ABS(
             portfolio_potential_sales_inr
             - 9356605.50
         ) < 0.01

         AND ABS(
             portfolio_associated_cost_inr
             - 6285399.67
         ) < 0.01

         AND ABS(
             portfolio_margin_exposure_inr
             - 3071205.83
         ) < 0.01

        THEN 'PASS'

        ELSE 'REVIEW'

    END AS dimension_reconciliation_status

FROM ranked_segments

ORDER BY

    FIELD(
        dimension_type,
        'WAREHOUSE',
        'CATEGORY',
        'SUPPLIER'
    ),

    financial_exposure_rank,

    segment_name;
    -- =========================================================
-- SECTION 08.2: VERIFIED FINANCIAL EXPOSURE
--               CONCENTRATION ANALYSIS
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
-- ANALYSIS DIMENSIONS:
-- Warehouse, Category, Supplier
--
-- OUTPUT:
-- 21 Segment Rows x 20 Columns
--
-- VALIDATION STATUS:
-- VERIFIED - PASS
--
-- Reconciled Segment Rows       : 21 / 21
-- Independent Dimensions       : 3 / 3
-- Financial Bridge Differences : INR 0.00
--
-- =========================================================
-- A. COMPANY-WIDE FINANCIAL BENCHMARKS
-- =========================================================
--
-- Inventory Locations              : 360
-- Stockout Locations               : 79
--
-- Total Unfulfilled Units          : 3681
--
-- Potential Unmet Sales Value:
-- INR 9356605.50
--
-- Associated Product Cost:
-- INR 6285399.67
--
-- Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- Financial Reconciliation:
-- 9356605.50 - 6285399.67 = 3071205.83
--
-- Overall Bridge Difference:
-- INR 0.00
--
-- =========================================================
-- B. INDEPENDENT DIMENSION RECONCILIATION
-- =========================================================
--
-- WAREHOUSE:
-- Number of Groups                 : 3
-- Inventory Locations              : 360
-- Stockout Locations               : 79
-- Unfulfilled Units                : 3681
-- Potential Sales INR              : 9356605.50
-- Associated Cost INR              : 6285399.67
-- Potential Margin INR             : 3071205.83
-- Status                           : PASS
--
-- CATEGORY:
-- Number of Groups                 : 6
-- Inventory Locations              : 360
-- Stockout Locations               : 79
-- Unfulfilled Units                : 3681
-- Potential Sales INR              : 9356605.50
-- Associated Cost INR              : 6285399.67
-- Potential Margin INR             : 3071205.83
-- Status                           : PASS
--
-- SUPPLIER:
-- Number of Groups                 : 12
-- Inventory Locations              : 360
-- Stockout Locations               : 79
-- Unfulfilled Units                : 3681
-- Potential Sales INR              : 9356605.50
-- Associated Cost INR              : 6285399.67
-- Potential Margin INR             : 3071205.83
-- Status                           : PASS
--
-- IMPORTANT:
-- Each dimension represents a different
-- grouping of the same inventory records.
--
-- Do not add warehouse, category and
-- supplier financial totals together.
--
-- =========================================================
-- C. WAREHOUSE FINANCIAL RANKINGS
-- =========================================================
--
-- RANK 1 - WEST
--
-- Inventory Locations              : 120
-- Stockout Locations               : 27
-- Demand Units                     : 16549
-- Unfulfilled Units                : 1309
-- Unfulfilled Demand Rate          : 7.91%
-- Potential Margin Exposure INR    : 1129395.17
-- Financial Exposure Share         : 36.77%
-- Margin Per Unfulfilled Unit INR  : 862.79
--
-- RANK 2 - SOUTH
--
-- Inventory Locations              : 120
-- Stockout Locations               : 30
-- Demand Units                     : 16723
-- Unfulfilled Units                : 1331
-- Unfulfilled Demand Rate          : 7.96%
-- Potential Margin Exposure INR    : 1022586.75
-- Financial Exposure Share         : 33.30%
-- Margin Per Unfulfilled Unit INR  : 768.28
--
-- RANK 3 - NORTH
--
-- Inventory Locations              : 120
-- Stockout Locations               : 22
-- Demand Units                     : 18331
-- Unfulfilled Units                : 1041
-- Unfulfilled Demand Rate          : 5.68%
-- Potential Margin Exposure INR    : 919223.91
-- Financial Exposure Share         : 29.93%
-- Margin Per Unfulfilled Unit INR  : 883.02
--
-- WAREHOUSE RECONCILIATION:
--
-- Unfulfilled Units:
-- 1309 + 1331 + 1041 = 3681
--
-- Potential Margin Exposure:
-- 1129395.17 + 1022586.75 + 919223.91
-- = INR 3071205.83
--
-- BUSINESS FINDING:
-- West has the greatest financial exposure.
--
-- South has the greatest unfulfilled
-- demand volume and slightly higher
-- unmet demand rate.
--
-- North has the highest average potential
-- margin per unfulfilled unit among warehouses.
--
-- =========================================================
-- D. CATEGORY FINANCIAL RANKINGS
-- =========================================================
--
-- CATEGORY             UNMET UNITS     MARGIN INR    SHARE
--
-- Home & Living             1769       1297842.85    42.26%
-- Home Appliances            561        913261.47    29.74%
-- Sports                     496        397473.32    12.94%
-- Electronics                206        228906.44     7.45%
-- Fashion                    354        154865.32     5.04%
-- Beauty                     295         78856.43     2.57%
--
-- CATEGORY RECONCILIATION:
--
-- Unfulfilled Units:
-- 1769 + 561 + 496 + 206 + 354 + 295
-- = 3681
--
-- Potential Margin Exposure:
-- INR 3071205.83
--
-- =========================================================
-- E. TOP-TWO CATEGORY FINANCIAL CONCENTRATION
-- =========================================================
--
-- Home & Living Exposure INR:
-- 1297842.85
--
-- Home Appliances Exposure INR:
-- 913261.47
--
-- Combined Exposure INR:
-- 2211104.32
--
-- Combined Exposure Share:
-- 2211104.32 / 3071205.83 * 100
-- = 71.99%
--
-- Combined Unfulfilled Units:
-- 1769 + 561 = 2330
--
-- Share of Unfulfilled Units:
-- 2330 / 3681 * 100 = 63.30%
--
-- BUSINESS FINDING:
-- Two categories contribute 71.99%
-- of October potential margin exposure.
--
-- =========================================================
-- F. HOME & LIVING OPERATIONAL RISK
-- =========================================================
--
-- Demand Units                     : 10361
-- Unfulfilled Units                : 1769
--
-- Unfulfilled Demand Rate:
-- 1769 / 10361 * 100 = 17.07%
--
-- Company Unfulfilled Demand Rate  : 7.13%
--
-- Relative Rate:
-- 17.07 / 7.13 = approximately 2.39
--
-- Share of Portfolio Unmet Units   : 48.06%
-- Share of Financial Exposure      : 42.26%
--
-- Potential Margin Exposure INR:
-- 1297842.85
--
-- BUSINESS FINDING:
-- Home & Living has the highest category-level
-- shortage volume and unmet demand rate.
--
-- It requires operational shortage investigation.
--
-- =========================================================
-- G. HOME APPLIANCES FINANCIAL IMPORTANCE
-- =========================================================
--
-- Unfulfilled Units                : 561
-- Share of Portfolio Unmet Units   : 15.24%
--
-- Potential Margin Exposure INR:
-- 913261.47
--
-- Share of Portfolio Exposure      : 29.74%
--
-- Margin Per Unfulfilled Unit INR:
-- 1627.92
--
-- Company Margin Per Unfulfilled Unit:
-- INR 834.34
--
-- Relative Financial Value:
-- 1627.92 / 834.34
-- = approximately 1.95
--
-- BUSINESS FINDING:
-- Home Appliances has disproportionately
-- high potential margin exposure compared
-- with its shortage volume.
--
-- Financial prioritization should not
-- depend on unmet units alone.
--
-- =========================================================
-- H. SUPPLIER-ASSOCIATED FINANCIAL RANKINGS
-- =========================================================
--
-- SUPPLIER  UNMET UNITS   MARGIN INR    FINANCIAL SHARE
--
-- SUP005        1012      952652.45        31.02%
-- SUP011         331      504038.56        16.41%
-- SUP012         230      409222.91        13.32%
-- SUP006         757      345190.40        11.24%
-- SUP010         345      286245.67         9.32%
-- SUP001         140      130180.84         4.24%
-- SUP009         151      111227.65         3.62%
-- SUP003         243      106164.38         3.46%
-- SUP002          66       98725.60         3.21%
-- SUP004         111       48700.94         1.59%
-- SUP008         119       41350.25         1.35%
-- SUP007         176       37506.18         1.22%
--
-- All 12 supplier groups reconciled.
--
-- =========================================================
-- I. TOP-THREE SUPPLIER CONCENTRATION
-- =========================================================
--
-- SUP005 Exposure INR:
-- 952652.45
--
-- SUP011 Exposure INR:
-- 504038.56
--
-- SUP012 Exposure INR:
-- 409222.91
--
-- Combined Exposure INR:
-- 1865913.92
--
-- Financial Contribution:
-- 1865913.92 / 3071205.83 * 100
-- = 60.76%
--
-- Combined Unfulfilled Units:
-- 1012 + 331 + 230 = 1573
--
-- Unfulfilled Unit Share:
-- 1573 / 3681 * 100 = 42.73%
--
-- BUSINESS FINDING:
-- Three supplier-associated product portfolios
-- contribute 60.76% of financial exposure.
--
-- This measures association, not proven
-- supplier-caused losses.
--
-- =========================================================
-- J. CROSS-DIMENSIONAL OBSERVATIONS
-- =========================================================
--
-- SUP005 + SUP006:
--
-- Unfulfilled Units:
-- 1012 + 757 = 1769
--
-- Stockout Locations:
-- 10 + 10 = 20
--
-- Potential Margin Exposure:
-- 952652.45 + 345190.40
-- = 1297842.85
--
-- These values match Home & Living's
-- October shortage and financial metrics.
--
-- SUP011 + SUP012:
--
-- Unfulfilled Units:
-- 331 + 230 = 561
--
-- Potential Margin Exposure:
-- 504038.56 + 409222.91
-- = 913261.47
--
-- These values match Home Appliances.
--
-- IMPORTANT:
-- Supplier-category metric equivalence
-- is observed in this synthetic dataset.
--
-- It does not establish causation.
--
-- =========================================================
-- K. SUPPLIER RELIABILITY VERSUS FINANCIAL RISK
-- =========================================================
--
-- Previously Verified Section 06 Findings:
--
-- SUP007:
-- October On-Time Delivery Rate    : 75.81%
-- Associated Margin Exposure INR   : 37506.18
-- Portfolio Exposure Share         : 1.22%
--
-- SUP011:
-- October On-Time Delivery Rate    : 100.00%
-- Associated Margin Exposure INR   : 504038.56
-- Portfolio Exposure Share         : 16.41%
--
-- BUSINESS INTERPRETATION:
-- Supplier delivery reliability and inventory
-- financial exposure are distinct measures.
--
-- High associated exposure does not prove
-- supplier delivery failure caused shortages.
--
-- =========================================================
-- L. SQL TECHNIQUES
-- =========================================================
--
-- COUNT(DISTINCT sku_id):
-- Counts unique products within each segment.
--
-- UNION ALL:
-- Combines three independent dimension views.
--
-- PARTITION BY dimension_type:
-- Separates warehouse, category and supplier
-- portfolio totals and rankings.
--
-- DENSE_RANK():
-- Assigns financial rankings within
-- each business dimension.
--
-- SUM(...) OVER (PARTITION BY ...):
-- Computes independent portfolio totals.
--
-- CUMULATIVE WINDOW SUM:
-- Calculates concentration in rank order.
--
-- NULLIF(..., 0):
-- Prevents division by zero.
--
-- =========================================================
-- M. BUSINESS IMPLICATIONS
-- =========================================================
--
-- WAREHOUSE:
-- Investigate West's financial exposure
-- and South's shortage-volume severity.
--
-- CATEGORY:
-- Investigate Home & Living's high
-- unfulfilled demand rate.
--
-- FINANCIAL CATEGORY:
-- Evaluate Home Appliances because its
-- unmet units carry higher unit margins.
--
-- SUPPLIER PORTFOLIOS:
-- Review SUP005, SUP011 and SUP012
-- for financially material inventory issues.
--
-- RECOMMENDATION DESIGN:
-- Use these findings with inventory-risk,
-- stockout recurrence and delivery data.
--
-- Do not recommend blanket stock increases
-- based on financial ranking alone.
--
-- =========================================================
-- N. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business data.
--
-- 2. Potential exposure is not booked
--    revenue loss or realized profit loss.
--
-- 3. Supplier association is not
--    proof of supplier-caused shortages.
--
-- 4. Portfolio dimensions overlap.
--    Do not add totals across dimensions.
--
-- 5. Financial concentration does not
--    establish replenishment feasibility.
--
-- 6. Unit selling price and cost are
--    modeled input values.
--
-- 7. Recovery costs and operational
--    constraints are not included.
--
-- 8. This section describes October 2026.
--
-- 9. Recovery scenario assumptions
--    have not yet been evaluated.
--
-- =========================================================
-- SECTION 08.2 STATUS:
-- VERIFIED - PASS
--
-- NEXT:
-- SECTION 08.3 - RECOVERY SCENARIOS
-- =========================================================
-- =========================================================
-- SECTION 08.3: RECOVERY SCENARIO & SENSITIVITY ANALYSIS
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
-- 1. What if 10%, 25%, or 50% of unmet demand
--    could be fulfilled?
-- 2. How much gross contribution might
--    this theoretically recover?
-- 3. What happens when additional execution
--    costs are included?
-- 4. How would the modeled fill rate change?
-- 5. How much potential exposure would remain?
--
-- RECOVERY ASSUMPTIONS:
-- 10%, 25%, 50%
--
-- ADDITIONAL COST ASSUMPTIONS:
-- 0%, 10%, 20% of recovered gross margin
--
-- EXPECTED OUTPUT:
-- 9 scenario combinations
--
-- IMPORTANT:
-- Recovery rates and cost percentages are
-- illustrative assumptions, NOT forecasts.
--
-- =========================================================


WITH october_financial_base AS (

    SELECT

        demand_units,

        fulfilled_units,

        demand_units - fulfilled_units
            AS unfulfilled_units,

        -- Estimated selling value of unmet demand
        (demand_units - fulfilled_units)
        * unit_selling_price
            AS unmet_sales_value_inr,

        -- Associated product cost of unmet units
        (demand_units - fulfilled_units)
        * unit_cost
            AS unmet_product_cost_inr,

        -- Potential gross-margin exposure
        (demand_units - fulfilled_units)
        * GREATEST(
            unit_selling_price - unit_cost,
            0
        ) AS potential_margin_exposure_inr,

        -- Current modeled fulfilled gross contribution
        fulfilled_units
        * (unit_selling_price - unit_cost)
            AS fulfilled_gross_contribution_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

-- =========================================================
-- STEP 2: BUILD VERIFIED OCTOBER BASELINE
-- =========================================================

october_portfolio AS (

    SELECT

        COUNT(*) AS inventory_locations,

        SUM(demand_units)
            AS total_demand_units,

        SUM(fulfilled_units)
            AS total_fulfilled_units,

        SUM(unfulfilled_units)
            AS total_unfulfilled_units,

        SUM(unmet_sales_value_inr)
            AS total_unmet_sales_inr,

        SUM(unmet_product_cost_inr)
            AS total_unmet_cost_inr,

        SUM(potential_margin_exposure_inr)
            AS total_potential_margin_inr,

        SUM(fulfilled_gross_contribution_inr)
            AS total_fulfilled_contribution_inr

    FROM october_financial_base

),

-- =========================================================
-- STEP 3: DEFINE THREE RECOVERY ASSUMPTIONS
-- =========================================================

recovery_assumptions AS (

    SELECT
        'LOW RECOVERY' AS recovery_scenario,
        0.10 AS recovery_rate

    UNION ALL

    SELECT
        'MODERATE RECOVERY',
        0.25

    UNION ALL

    SELECT
        'HIGH RECOVERY',
        0.50

),

-- =========================================================
-- STEP 4: DEFINE THREE EXTRA-COST ASSUMPTIONS
-- =========================================================

cost_assumptions AS (

    SELECT
        'NO EXTRA EXECUTION COST' AS cost_scenario,
        0.00 AS incremental_cost_rate

    UNION ALL

    SELECT
        '10% OF RECOVERED MARGIN',
        0.10

    UNION ALL

    SELECT
        '20% OF RECOVERED MARGIN',
        0.20

),

-- =========================================================
-- STEP 5: CREATE ALL NINE SCENARIO COMBINATIONS
-- =========================================================

scenario_grid AS (

    SELECT

        r.recovery_scenario,

        r.recovery_rate,

        c.cost_scenario,

        c.incremental_cost_rate,

        p.inventory_locations,

        p.total_demand_units,

        p.total_fulfilled_units,

        p.total_unfulfilled_units,

        p.total_unmet_sales_inr,

        p.total_unmet_cost_inr,

        p.total_potential_margin_inr,

        p.total_fulfilled_contribution_inr,

        -- Expected-equivalent recovered units
        p.total_unfulfilled_units
        * r.recovery_rate
            AS recovered_unit_equivalents,

        -- Expected-equivalent unmet units remaining
        p.total_unfulfilled_units
        * (1 - r.recovery_rate)
            AS remaining_unfulfilled_equivalents,

        -- Modeled recovered sales value
        p.total_unmet_sales_inr
        * r.recovery_rate
            AS recovered_sales_inr,

        -- Product cost associated with recovery
        p.total_unmet_cost_inr
        * r.recovery_rate
            AS recovered_product_cost_inr,

        -- Modeled recovered gross margin
        p.total_potential_margin_inr
        * r.recovery_rate
            AS recovered_gross_margin_inr,

        -- Remaining potential margin exposure
        p.total_potential_margin_inr
        * (1 - r.recovery_rate)
            AS remaining_margin_exposure_inr,

        -- Extra cost expressed as a proportion
        -- of recovered gross margin
        p.total_potential_margin_inr
        * r.recovery_rate
        * c.incremental_cost_rate
            AS incremental_execution_cost_inr

    FROM october_portfolio p

    CROSS JOIN recovery_assumptions r

    CROSS JOIN cost_assumptions c

),

-- =========================================================
-- STEP 6: CALCULATE CONTRIBUTION AND FILL-RATE IMPACT
-- =========================================================

scenario_results AS (

    SELECT

        scenario_grid.*,

        -- Gross contribution less additional
        -- execution cost, after modeled COGS
        recovered_gross_margin_inr
        - incremental_execution_cost_inr
            AS net_incremental_contribution_inr,

        -- Theoretical fill rate after recovery
        (
            total_fulfilled_units
            + recovered_unit_equivalents
        ) * 100.0 /
        NULLIF(total_demand_units, 0)
            AS modeled_fill_rate_pct,

        -- Improvement in percentage points
        recovered_unit_equivalents
        * 100.0 /
        NULLIF(total_demand_units, 0)
            AS fill_rate_improvement_pp,

        -- Current fulfilled contribution plus
        -- modeled incremental contribution
        total_fulfilled_contribution_inr
        + recovered_gross_margin_inr
        - incremental_execution_cost_inr
            AS modeled_total_contribution_inr

    FROM scenario_grid

)

-- =========================================================
-- STEP 7: FINAL RECOVERY SCENARIO SCORECARD
-- =========================================================

SELECT

    recovery_scenario,

    ROUND(
        recovery_rate * 100,
        2
    ) AS recovery_rate_pct,

    cost_scenario,

    ROUND(
        incremental_cost_rate * 100,
        2
    ) AS incremental_cost_pct_of_margin,

    ROUND(
        recovered_unit_equivalents,
        2
    ) AS recovered_unit_equivalents,

    ROUND(
        remaining_unfulfilled_equivalents,
        2
    ) AS remaining_unfulfilled_unit_equivalents,

    ROUND(
        modeled_fill_rate_pct,
        2
    ) AS modeled_fill_rate_pct,

    ROUND(
        fill_rate_improvement_pp,
        2
    ) AS fill_rate_improvement_pp,

    ROUND(
        recovered_sales_inr,
        2
    ) AS recovered_sales_value_inr,

    ROUND(
        recovered_product_cost_inr,
        2
    ) AS recovered_product_cost_inr,

    ROUND(
        recovered_gross_margin_inr,
        2
    ) AS recovered_gross_margin_inr,

    ROUND(
        incremental_execution_cost_inr,
        2
    ) AS incremental_execution_cost_inr,

    ROUND(
        net_incremental_contribution_inr,
        2
    ) AS net_incremental_contribution_inr,

    ROUND(
        remaining_margin_exposure_inr,
        2
    ) AS remaining_margin_exposure_inr,

    ROUND(
        modeled_total_contribution_inr,
        2
    ) AS modeled_total_contribution_inr,

    -- Portfolio reconciliation benchmarks
    total_demand_units
        AS portfolio_demand_units,

    total_unfulfilled_units
        AS portfolio_original_unfulfilled_units,

    ROUND(
        total_potential_margin_inr,
        2
    ) AS portfolio_potential_margin_inr,

    -- Recovered selling value must reconcile
    -- to recovered cost plus gross margin
    ROUND(
        recovered_sales_inr
        - recovered_product_cost_inr
        - recovered_gross_margin_inr,
        2
    ) AS financial_bridge_difference_inr,

    -- Scenario quality assurance
    CASE

        WHEN inventory_locations = 360

         AND total_demand_units = 51603

         AND total_fulfilled_units = 47922

         AND total_unfulfilled_units = 3681

         AND ABS(
             total_unmet_sales_inr - 9356605.50
         ) < 0.01

         AND ABS(
             total_unmet_cost_inr - 6285399.67
         ) < 0.01

         AND ABS(
             total_potential_margin_inr - 3071205.83
         ) < 0.01

         AND ABS(
             total_fulfilled_contribution_inr
             - 44864064.22
         ) < 0.01

         AND ABS(
             recovered_sales_inr
             - recovered_product_cost_inr
             - recovered_gross_margin_inr
         ) < 0.01

         AND ABS(
             recovered_gross_margin_inr
             + remaining_margin_exposure_inr
             - total_potential_margin_inr
         ) < 0.01

         AND ABS(
             recovered_unit_equivalents
             + remaining_unfulfilled_equivalents
             - total_unfulfilled_units
         ) < 0.000001

         AND ABS(
             recovered_gross_margin_inr
             - incremental_execution_cost_inr
             - net_incremental_contribution_inr
         ) < 0.01

         AND recovery_rate BETWEEN 0 AND 1

         AND incremental_cost_rate BETWEEN 0 AND 1

        THEN 'PASS'

        ELSE 'REVIEW'

    END AS scenario_qa_status

FROM scenario_results

ORDER BY
    recovery_rate,
    incremental_cost_rate;
    -- =========================================================
-- SECTION 08.3: VERIFIED RECOVERY SCENARIO
--               & FINANCIAL SENSITIVITY ANALYSIS
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
-- 9 Scenario Rows x 20 Columns
--
-- VALIDATION STATUS:
-- VERIFIED - PASS
--
-- Scenario Combinations Executed : 9
-- Scenario Checks Passed         : 9
-- Scenario Checks Failed         : 0
-- Financial Bridge Differences   : INR 0.00
--
-- =========================================================
-- A. VERIFIED OCTOBER BASELINE
-- =========================================================
--
-- Inventory Locations                 : 360
--
-- Customer Demand Units               : 51603
-- Fulfilled Units                     : 47922
-- Unfulfilled Units                   : 3681
--
-- Original Fill Rate                  : 92.87%
--
-- Potential Unmet Sales Value:
-- INR 9356605.50
--
-- Associated Product Cost:
-- INR 6285399.67
--
-- Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- Modeled Fulfilled Gross Contribution:
-- INR 44864064.22
--
-- All baseline reconciliation checks passed.
--
-- =========================================================
-- B. SCENARIO DESIGN
-- =========================================================
--
-- RECOVERY ASSUMPTIONS:
--
-- Low Recovery                    : 10%
-- Moderate Recovery               : 25%
-- High Recovery                   : 50%
--
-- ADDITIONAL EXECUTION COST:
--
-- No Extra Cost                   : 0%
-- Moderate Extra Cost             : 10%
-- Higher Extra Cost               : 20%
--
-- Execution-cost percentages are applied
-- to recovered gross margin, not sales value.
--
-- Total Scenario Combinations:
-- 3 Recovery Rates x 3 Cost Rates = 9
--
-- All percentages are illustrative planning
-- assumptions, not statistically estimated
-- forecasts or probabilities.
--
-- =========================================================
-- C. OPERATIONAL RECOVERY RESULTS
-- =========================================================
--
-- LOW RECOVERY - 10%
--
-- Recovered Unit Equivalents       : 368.10
-- Remaining Unfulfilled Equivalents: 3312.90
-- Modeled Fill Rate                : 93.58%
-- Fill Rate Improvement            : 0.71 pp
--
-- Recovered Sales Value INR        : 935660.55
-- Recovered Product Cost INR       : 628539.97
-- Recovered Gross Margin INR       : 307120.58
-- Remaining Exposure INR           : 2764085.25
--
-- ---------------------------------------------------------
--
-- MODERATE RECOVERY - 25%
--
-- Recovered Unit Equivalents       : 920.25
-- Remaining Unfulfilled Equivalents: 2760.75
-- Modeled Fill Rate                : 94.65%
-- Fill Rate Improvement            : 1.78 pp
--
-- Recovered Sales Value INR        : 2339151.38
-- Recovered Product Cost INR       : 1571349.92
-- Recovered Gross Margin INR       : 767801.46
-- Remaining Exposure INR           : 2303404.37
--
-- ---------------------------------------------------------
--
-- HIGH RECOVERY - 50%
--
-- Recovered Unit Equivalents       : 1840.50
-- Remaining Unfulfilled Equivalents: 1840.50
-- Modeled Fill Rate                : 96.43%
-- Fill Rate Improvement            : 3.57 pp
--
-- Recovered Sales Value INR        : 4678302.75
-- Recovered Product Cost INR       : 3142699.84
-- Recovered Gross Margin INR       : 1535602.92
-- Remaining Exposure INR           : 1535602.92
--
-- =========================================================
-- D. ALL NINE NET CONTRIBUTION SCENARIOS
-- =========================================================
--
-- RECOVERY: 10%
--
-- Extra Cost 0%:
-- Recovered Gross Margin INR       : 307120.58
-- Additional Execution Cost INR    : 0.00
-- Net Incremental Contribution INR : 307120.58
--
-- Extra Cost 10%:
-- Additional Execution Cost INR    : 30712.06
-- Net Incremental Contribution INR : 276408.52
--
-- Extra Cost 20%:
-- Additional Execution Cost INR    : 61424.12
-- Net Incremental Contribution INR : 245696.47
--
-- ---------------------------------------------------------
--
-- RECOVERY: 25%
--
-- Extra Cost 0%:
-- Recovered Gross Margin INR       : 767801.46
-- Additional Execution Cost INR    : 0.00
-- Net Incremental Contribution INR : 767801.46
--
-- Extra Cost 10%:
-- Additional Execution Cost INR    : 76780.15
-- Net Incremental Contribution INR : 691021.31
--
-- Extra Cost 20%:
-- Additional Execution Cost INR    : 153560.29
-- Net Incremental Contribution INR : 614241.17
--
-- ---------------------------------------------------------
--
-- RECOVERY: 50%
--
-- Extra Cost 0%:
-- Recovered Gross Margin INR       : 1535602.92
-- Additional Execution Cost INR    : 0.00
-- Net Incremental Contribution INR : 1535602.92
--
-- Extra Cost 10%:
-- Additional Execution Cost INR    : 153560.29
-- Net Incremental Contribution INR : 1382042.62
--
-- Extra Cost 20%:
-- Additional Execution Cost INR    : 307120.58
-- Net Incremental Contribution INR : 1228482.33
--
-- ALL NINE SCENARIOS: PASS
--
-- =========================================================
-- E. MODELED TOTAL CONTRIBUTION
-- =========================================================
--
-- Baseline Fulfilled Gross Contribution:
-- INR 44864064.22
--
-- Recovery 10%:
-- Extra Cost 0%                   : 45171184.80
-- Extra Cost 10%                  : 45140472.74
-- Extra Cost 20%                  : 45109760.69
--
-- Recovery 25%:
-- Extra Cost 0%                   : 45631865.68
-- Extra Cost 10%                  : 45555085.53
-- Extra Cost 20%                  : 45478305.39
--
-- Recovery 50%:
-- Extra Cost 0%                   : 46399667.14
-- Extra Cost 10%                  : 46246106.84
-- Extra Cost 20%                  : 46092546.55
--
-- These figures are modeled gross contribution
-- after the specified incremental execution
-- cost assumption.
--
-- They are NOT realized accounting profit.
--
-- =========================================================
-- F. MIDDLE ILLUSTRATIVE CASE
-- =========================================================
--
-- Recovery Assumption            : 25%
-- Additional Cost Assumption     : 10%
--
-- Recovered Unit Equivalents     : 920.25
-- Modeled Fill Rate              : 94.65%
-- Fill Rate Improvement          : 1.78 pp
--
-- Recovered Sales INR            : 2339151.38
-- Recovered Product Cost INR     : 1571349.92
-- Recovered Gross Margin INR     : 767801.46
--
-- Additional Execution Cost INR  : 76780.15
--
-- Net Incremental Contribution:
-- INR 691021.31
--
-- Remaining Margin Exposure:
-- INR 2303404.37
--
-- IMPORTANT:
-- This is a middle illustrative scenario,
-- not a predicted or most likely outcome.
--
-- =========================================================
-- G. SCENARIO FORMULAS
-- =========================================================
--
-- RECOVERED UNIT EQUIVALENTS:
-- unfulfilled_units * recovery_rate
--
-- RECOVERED SALES VALUE:
-- potential_unmet_sales * recovery_rate
--
-- RECOVERED PRODUCT COST:
-- associated_unmet_cost * recovery_rate
--
-- RECOVERED GROSS MARGIN:
-- potential_margin_exposure * recovery_rate
--
-- ADDITIONAL EXECUTION COST:
-- recovered_gross_margin * incremental_cost_rate
--
-- MODELED NET INCREMENTAL CONTRIBUTION:
-- recovered_gross_margin
-- - additional_execution_cost
--
-- REMAINING FINANCIAL EXPOSURE:
-- original_potential_margin * (1 - recovery_rate)
--
-- MODELED FILL RATE:
-- (fulfilled_units + recovered_unit_equivalents)
-- / total_demand_units * 100
--
-- FILL RATE IMPROVEMENT:
-- recovered_unit_equivalents
-- / total_demand_units * 100
--
-- =========================================================
-- H. RECONCILIATION CHECKS
-- =========================================================
--
-- 1. Original Inventory Locations       PASS
-- 2. Original Demand Units              PASS
-- 3. Original Fulfilled Units           PASS
-- 4. Original Unfulfilled Units         PASS
-- 5. Unmet Sales Value                  PASS
-- 6. Associated Product Cost            PASS
-- 7. Original Potential Margin          PASS
-- 8. Fulfilled Gross Contribution       PASS
-- 9. Recovered Sales-Cost-Margin Bridge PASS
-- 10. Recovered + Remaining Margin      PASS
-- 11. Recovered + Remaining Units       PASS
-- 12. Gross Less Execution Cost         PASS
-- 13. Recovery Assumption Range         PASS
-- 14. Execution-Cost Assumption Range   PASS
--
-- Overall Scenario QA:
-- 9 of 9 scenario rows returned PASS.
--
-- IMPORTANT ROUNDING NOTE:
-- All financial calculations and QA checks
-- use full precision before display rounding.
--
-- Separately rounded output columns may
-- show a difference of INR 0.01 when
-- manually subtracted.
--
-- Example:
-- High Recovery, 10% Extra Cost:
--
-- Displayed Gross Margin       : 1535602.92
-- Displayed Execution Cost     : 153560.29
-- Displayed Net Contribution   : 1382042.62
--
-- The net result is calculated using full
-- precision before rounding, not by
-- subtracting the displayed values.
--
-- Financial Bridge Difference:
-- INR 0.00 in all nine scenario outputs.
--
-- =========================================================
-- I. KEY BUSINESS FINDINGS
-- =========================================================
--
-- 1. A 10% recovery assumption increases
--    modeled fill rate to 93.58%.
--
-- 2. A 25% recovery assumption increases
--    modeled fill rate to 94.65%.
--
-- 3. A 50% recovery assumption increases
--    modeled fill rate to 96.43%.
--
-- 4. At 25% recovery and 10% extra cost,
--    net incremental contribution is
--    modeled at INR 691021.31.
--
-- 5. At 50% recovery and 20% extra cost,
--    net incremental contribution is
--    modeled at INR 1228482.33.
--
-- 6. Higher execution costs reduce modeled
--    net contribution at a fixed recovery rate.
--
-- 7. Recovery rates affect operating and
--    financial outputs; cost rates affect
--    modeled contribution but not fill rate.
--
-- 8. Remaining financial exposure persists
--    under every modeled recovery scenario.
--
-- =========================================================
-- J. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business scenario.
--
-- 2. Recovery percentages are assumptions,
--    not forecasts or probabilities.
--
-- 3. Incremental cost percentages are
--    illustrative, not measured costs.
--
-- 4. Recovery is assumed proportional
--    across the original unmet-demand mix.
--
-- 5. Actual SKU-level recovery feasibility
--    has not been established.
--
-- 6. Fractional recovered units are
--    expected-equivalent units.
--
-- 7. Fixed customer demand and existing
--    unit selling prices are assumed.
--
-- 8. Open orders, future demand changes,
--    substitutions and recovery delays
--    are not explicitly modeled.
--
-- 9. Incremental fixed implementation costs
--    and all other indirect costs are
--    not included.
--
-- 10. Modeled net incremental contribution
--     is not realized net profit.
--
-- 11. Nine scenarios are alternatives.
--     Do not add their financial benefits.
--
-- 12. Positive scenario contributions do
--     not prove operational feasibility.
--
-- =========================================================
-- SECTION 08.3 STATUS:
-- VERIFIED - 9/9 PASS
--
-- NEXT:
-- SECTION 08.4 - BUSINESS RECOMMENDATIONS
-- =========================================================
-- =========================================================
-- SECTION 08.4: FINANCIALLY PRIORITIZED
--               BUSINESS RECOMMENDATIONS
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
--
-- DECISION PERIOD:
-- October 2026
--
-- HISTORICAL CONTEXT:
-- November 2025 through October 2026
--
-- PURPOSE:
-- Rank non-overlapping inventory improvement
-- workstreams and assign proposed actions,
-- owners and measurable success indicators.
--
-- GRAIN:
-- One Category x Warehouse
--
-- EXPECTED:
-- 6 Categories x 3 Warehouses = 18 Groups
--
-- PRIORITY TIERS (ILLUSTRATIVE):
-- P1: Financial Ranks 1-3
-- P2: Financial Ranks 4-8
-- P3: Financial Ranks 9-18
--
-- FINANCIAL SCENARIO:
-- 25% assumed demand recovery
-- 10% extra cost on recovered gross margin
--
-- NOTE:
-- This is an illustrative opportunity
-- estimate, not a forecast or approved target.
-- =========================================================


WITH historical_location_risk AS (

    SELECT
        sku_id,
        warehouse,

        COUNT(DISTINCT reporting_month)
            AS historical_months_observed,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS historical_stockout_months

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month BETWEEN
        '2025-11-01' AND '2026-10-01'

    GROUP BY
        sku_id,
        warehouse
),

-- =========================================================
-- STEP 2: PREPARE OCTOBER SKU-WAREHOUSE EVIDENCE
-- =========================================================

october_evidence AS (

    SELECT
        i.category,
        i.warehouse,
        i.sku_id,

        i.demand_units,
        i.fulfilled_units,
        i.stockout_days,

        -- Current shortage
        CASE
            WHEN i.stockout_days > 0
            THEN 1 ELSE 0
        END AS stockout_flag,

        -- October zero closing stock
        CASE
            WHEN i.closing_stock_units = 0
            THEN 1 ELSE 0
        END AS zero_stock_flag,

        -- Positive closing stock below reorder
        CASE
            WHEN i.closing_stock_units > 0
             AND i.closing_stock_units < i.reorder_point_units
            THEN 1 ELSE 0
        END AS below_reorder_flag,

        -- Positive-stock reorder gap
        CASE
            WHEN i.closing_stock_units > 0
             AND i.closing_stock_units < i.reorder_point_units
            THEN i.reorder_point_units - i.closing_stock_units
            ELSE 0
        END AS reorder_gap_units,

        -- Historical recurring shortage indicator
        CASE
            WHEN h.historical_stockout_months >= 2
            THEN 1 ELSE 0
        END AS recurring_stockout_flag,

        -- Twelve-month history completeness
        CASE
            WHEN h.historical_months_observed = 12
            THEN 1 ELSE 0
        END AS complete_history_flag,

        -- Current unmet demand
        i.demand_units - i.fulfilled_units
            AS unfulfilled_units,

        -- Current potential gross-margin exposure
        (i.demand_units - i.fulfilled_units)
        * GREATEST(
            i.unit_selling_price - i.unit_cost,
            0
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory i

    LEFT JOIN historical_location_risk h
        ON i.sku_id = h.sku_id
       AND i.warehouse = h.warehouse

    WHERE i.reporting_month = '2026-10-01'
),

-- =========================================================
-- STEP 3: BUILD NON-OVERLAPPING ACTION GROUPS
-- =========================================================

recommendation_segments AS (

    SELECT
        category,
        warehouse,

        COUNT(*) AS sku_locations,

        SUM(stockout_flag)
            AS october_stockout_locations,

        SUM(zero_stock_flag)
            AS zero_stock_locations,

        SUM(below_reorder_flag)
            AS below_reorder_locations,

        SUM(recurring_stockout_flag)
            AS recurring_stockout_locations,

        SUM(complete_history_flag)
            AS complete_history_locations,

        SUM(stockout_days)
            AS october_stockout_days,

        SUM(reorder_gap_units)
            AS reorder_gap_units,

        SUM(demand_units)
            AS demand_units,

        SUM(unfulfilled_units)
            AS unfulfilled_units,

        SUM(potential_margin_exposure_inr)
            AS potential_margin_exposure_inr,

        -- Illustrative net contribution:
        -- 25% recovery x 90% retained margin
        SUM(potential_margin_exposure_inr)
        * 0.25 * (1 - 0.10)
            AS illustrative_net_contribution_inr

    FROM october_evidence

    GROUP BY
        category,
        warehouse
),

-- =========================================================
-- STEP 4: RANK ACTION GROUPS AND RECONCILE TOTALS
-- =========================================================

ranked_recommendations AS (

    SELECT
        s.*,

        ROW_NUMBER() OVER (
            ORDER BY
                potential_margin_exposure_inr DESC,
                unfulfilled_units DESC,
                category,
                warehouse
        ) AS financial_priority_rank,

        COUNT(*) OVER ()
            AS portfolio_action_groups,

        SUM(sku_locations) OVER ()
            AS portfolio_locations,

        SUM(october_stockout_locations) OVER ()
            AS portfolio_stockout_locations,

        SUM(zero_stock_locations) OVER ()
            AS portfolio_zero_stock_locations,

        SUM(below_reorder_locations) OVER ()
            AS portfolio_below_reorder_locations,

        SUM(recurring_stockout_locations) OVER ()
            AS portfolio_recurring_locations,

        SUM(complete_history_locations) OVER ()
            AS portfolio_complete_histories,

        SUM(reorder_gap_units) OVER ()
            AS portfolio_reorder_gap_units,

        SUM(unfulfilled_units) OVER ()
            AS portfolio_unfulfilled_units,

        SUM(potential_margin_exposure_inr) OVER ()
            AS portfolio_margin_exposure_inr,

        SUM(illustrative_net_contribution_inr) OVER ()
            AS portfolio_illustrative_contribution_inr,

        SUM(potential_margin_exposure_inr) OVER (
            ORDER BY
                potential_margin_exposure_inr DESC,
                unfulfilled_units DESC,
                category,
                warehouse
            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS cumulative_margin_exposure_inr

    FROM recommendation_segments s
)

-- =========================================================
-- STEP 5: MANAGEMENT ACTION & OWNERSHIP MATRIX
-- =========================================================

SELECT

    financial_priority_rank,

    -- Planning-based priority tier
    CASE
        WHEN financial_priority_rank <= 3
        THEN 'P1 - FIRST REVIEW'

        WHEN financial_priority_rank <= 8
        THEN 'P2 - NEXT WAVE'

        ELSE 'P3 - MONITOR / SELECTIVE REVIEW'
    END AS planning_priority,

    category,

    warehouse,

    sku_locations,

    october_stockout_locations,

    zero_stock_locations,

    below_reorder_locations,

    recurring_stockout_locations,

    october_stockout_days,

    unfulfilled_units,

    ROUND(
        unfulfilled_units * 100.0 /
        NULLIF(demand_units, 0),
        2
    ) AS unmet_demand_rate_pct,

    reorder_gap_units,

    ROUND(
        potential_margin_exposure_inr,
        2
    ) AS potential_margin_exposure_inr,

    ROUND(
        potential_margin_exposure_inr * 100.0 /
        NULLIF(portfolio_margin_exposure_inr, 0),
        2
    ) AS portfolio_exposure_share_pct,

    ROUND(
        cumulative_margin_exposure_inr * 100.0 /
        NULLIF(portfolio_margin_exposure_inr, 0),
        2
    ) AS cumulative_exposure_share_pct,

    -- Conditional recovery opportunity, not profit
    ROUND(
        illustrative_net_contribution_inr,
        2
    ) AS illustrative_net_contribution_inr,

    -- Proposed accountable role
    CONCAT(
        warehouse,
        ' Warehouse Inventory Manager'
    ) AS proposed_accountable_owner,

    -- Supporting business functions
    CASE
        WHEN category = 'Home Appliances'
        THEN 'Category Manager + Procurement'

        WHEN category = 'Home & Living'
        THEN 'Demand Planning + Procurement'

        ELSE 'Demand Planning + Procurement'
    END AS supporting_teams,

    -- Evidence-based investigation recommendation
    CASE
        WHEN category = 'Home & Living'
        THEN
            'Investigate high-volume shortage SKUs; '
            'review demand, allocation and replenishment'

        WHEN category = 'Home Appliances'
        THEN
            'Review high-value unmet demand; '
            'prioritize feasible margin-positive recovery'

        WHEN october_stockout_locations > 0
         AND recurring_stockout_locations > 0
        THEN
            'Investigate recurring shortages; '
            'validate demand and replenishment timing'

        WHEN october_stockout_locations > 0
        THEN
            'Investigate current stockouts and '
            'confirm economically feasible replenishment'

        WHEN below_reorder_locations > 0
        THEN
            'Review reorder triggers and lead-time coverage'

        ELSE
            'Maintain monitoring and validate inventory policy'

    END AS recommended_action,

    -- Proposed success measures
    CASE
        WHEN category = 'Home & Living'
        THEN
            'Monthly unmet-demand rate; '
            'stockout locations; recurring shortages'

        WHEN category = 'Home Appliances'
        THEN
            'Monthly potential margin exposure; '
            'fill rate; recovery economics'

        ELSE
            'Monthly unmet units; fill rate; '
            'potential margin exposure'
    END AS success_kpis,

    -- Operational decision gate
    'Validate customer recoverability, supplier lead '
    'time, stock feasibility and full execution costs'
        AS approval_gate,

    -- Company-wide reconciliation benchmarks
    portfolio_action_groups,

    portfolio_unfulfilled_units,

    ROUND(
        portfolio_margin_exposure_inr,
        2
    ) AS portfolio_margin_exposure_inr,

    ROUND(
        portfolio_illustrative_contribution_inr,
        2
    ) AS portfolio_illustrative_contribution_inr,

    -- Do not approve recommendations unless
    -- the underlying portfolio data reconciles
    CASE

        WHEN portfolio_action_groups = 18

         AND portfolio_locations = 360

         AND portfolio_stockout_locations = 79

         AND portfolio_zero_stock_locations = 79

         AND portfolio_below_reorder_locations = 141

         AND portfolio_recurring_locations = 216

         AND portfolio_complete_histories = 360

         AND portfolio_reorder_gap_units = 4544

         AND portfolio_unfulfilled_units = 3681

         AND ABS(
             portfolio_margin_exposure_inr
             - 3071205.83
         ) < 0.01

         AND ABS(
             portfolio_illustrative_contribution_inr
             - 691021.31
         ) < 0.01

        THEN 'PASS'

        ELSE 'REVIEW'

    END AS recommendation_qa_status

FROM ranked_recommendations

ORDER BY financial_priority_rank;
-- =========================================================
-- SECTION 08.4: VERIFIED FINANCIALLY PRIORITIZED
--               BUSINESS RECOMMENDATIONS
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
-- HISTORICAL RISK PERIOD:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- ANALYSIS GRAIN:
-- Category x Warehouse
--
-- VALIDATION STATUS:
-- VERIFIED - PASS
--
-- Recommendation Groups Returned : 18
-- Recommendation QA Results       : 18 PASS
-- Failed Reconciliations          : 0
--
-- =========================================================
-- A. COMPANY-WIDE BASELINE
-- =========================================================
--
-- Inventory Locations                 : 360
-- October Stockout Locations          : 79
-- October Below-Reorder Locations     : 141
-- Historical Recurring Locations      : 216
--
-- October Stockout Days               : 751
-- October Unfulfilled Units           : 3681
-- October Reorder Gap Units           : 4544
--
-- Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- ILLUSTRATIVE RECOVERY ASSUMPTIONS:
-- Demand Recovery                    : 25%
-- Incremental Cost on Recovered Margin: 10%
--
-- Portfolio Illustrative
-- Net Incremental Contribution:
-- INR 691021.31
--
-- This is modeled contribution, NOT
-- actual or guaranteed recovered profit.
--
-- =========================================================
-- B. NON-OVERLAPPING WORKSTREAM DESIGN
-- =========================================================
--
-- Six Product Categories
-- Three Warehouses
--
-- Total Workstreams:
-- 6 x 3 = 18
--
-- Each SKU-warehouse observation belongs
-- to one category and one warehouse.
--
-- Therefore, these 18 groups partition
-- October inventory without overlap.
--
-- Supplier-associated exposure is used
-- as supporting context, not added
-- as a separate financial opportunity.
--
-- =========================================================
-- C. FINANCIAL PRIORITY RULES
-- =========================================================
--
-- The ranking uses:
--
-- 1. Potential Margin Exposure DESC
-- 2. Unfulfilled Units DESC
-- 3. Category ASC
-- 4. Warehouse ASC
--
-- ROW_NUMBER() assigns one review rank
-- to each category-warehouse group.
--
-- P1 - FIRST REVIEW:
-- Financial Ranks 1 to 3
--
-- P2 - NEXT WAVE:
-- Financial Ranks 4 to 8
--
-- P3 - MONITOR / SELECTIVE REVIEW:
-- Financial Ranks 9 to 18
--
-- These are illustrative planning tiers,
-- not validated operational risk classes.
--
-- =========================================================
-- D. ALL 18 FINANCIAL WORKSTREAM RANKINGS
-- =========================================================
--
-- RANK CATEGORY           WAREHOUSE  EXPOSURE INR
--
--  1   Home & Living      South       575632.69
--  2   Home & Living      West        488275.98
--  3   Home Appliances    North       459738.32
--
--  4   Home Appliances    West        390149.63
--  5   Home & Living      North       233934.18
--  6   Sports             South       202300.55
--  7   Sports             West        104830.65
--  8   Electronics        South        97727.32
--
--  9   Electronics        West         96436.53
-- 10   Sports             North        90342.12
-- 11   Fashion            North        83684.78
-- 12   Home Appliances    South        63373.52
-- 13   Fashion            South        54449.69
-- 14   Electronics        North        34742.59
-- 15   Beauty             West         32971.53
-- 16   Beauty             South        29102.98
-- 17   Beauty             North        16781.92
-- 18   Fashion            West         16730.85
--
-- Financial Exposure Reconciliation:
-- INR 3071205.83
--
-- =========================================================
-- E. P1 - TOP THREE FINANCIAL WORKSTREAMS
-- =========================================================
--
-- PRIORITY 1:
-- HOME & LIVING - SOUTH
--
-- SKU Locations                    : 20
-- Stockout Locations               : 9
-- Below-Reorder Locations          : 5
-- Recurring Stockout Locations     : 15
--
-- October Stockout Days            : 128
-- Unfulfilled Units                : 802
-- Unfulfilled Demand Rate          : 24.62%
-- Reorder Gap Units                : 218
--
-- Potential Margin Exposure:
-- INR 575632.69
--
-- Portfolio Exposure Share:
-- 18.74%
--
-- Illustrative Net Contribution:
-- INR 129517.36
--
-- Proposed Accountable Owner:
-- South Warehouse Inventory Manager
--
-- Supporting Teams:
-- Demand Planning and Procurement
--
-- Proposed Investigation:
-- Identify high-volume shortage SKUs.
-- Review forecast accuracy, inventory
-- allocation, replenishment timing
-- and feasible stock recovery.
--
-- Success Measures:
-- Monthly unfulfilled units
-- Monthly unmet-demand rate
-- Current stockout locations
-- Repeated stockout locations
--
-- ---------------------------------------------------------
--
-- PRIORITY 2:
-- HOME & LIVING - WEST
--
-- SKU Locations                    : 20
-- Stockout Locations               : 7
-- Below-Reorder Locations          : 6
-- Recurring Stockout Locations     : 12
--
-- October Stockout Days            : 109
-- Unfulfilled Units                : 678
-- Unfulfilled Demand Rate          : 20.48%
-- Reorder Gap Units                : 84
--
-- Potential Margin Exposure:
-- INR 488275.98
--
-- Portfolio Exposure Share:
-- 15.90%
--
-- Illustrative Net Contribution:
-- INR 109862.10
--
-- Proposed Accountable Owner:
-- West Warehouse Inventory Manager
--
-- Supporting Teams:
-- Demand Planning and Procurement
--
-- Proposed Investigation:
-- Investigate persistent stockouts,
-- replenishment timing, stock allocation
-- and warehouse-specific demand.
--
-- Success Measures:
-- Monthly unfulfilled units
-- Monthly unmet-demand rate
-- Stockout locations
-- Historical recurrence
--
-- ---------------------------------------------------------
--
-- PRIORITY 3:
-- HOME APPLIANCES - NORTH
--
-- SKU Locations                    : 20
-- Stockout Locations               : 6
-- Below-Reorder Locations          : 4
-- Recurring Stockout Locations     : 13
--
-- October Stockout Days            : 60
-- Unfulfilled Units                : 297
-- Unfulfilled Demand Rate          : 10.46%
-- Reorder Gap Units                : 27
--
-- Potential Margin Exposure:
-- INR 459738.32
--
-- Portfolio Exposure Share:
-- 14.97%
--
-- Illustrative Net Contribution:
-- INR 103441.12
--
-- Proposed Accountable Owner:
-- North Warehouse Inventory Manager
--
-- Supporting Teams:
-- Category Management and Procurement
--
-- Proposed Investigation:
-- Identify financially material unmet
-- demand and verify feasible recovery
-- after product and execution costs.
--
-- Success Measures:
-- Monthly potential margin exposure
-- Fill rate
-- Recovery economics
-- Stockout recurrence
--
-- =========================================================
-- F. P1 COMBINED FINANCIAL CONCENTRATION
-- =========================================================
--
-- P1 Workstreams                    : 3
--
-- Combined Unfulfilled Units:
-- 802 + 678 + 297 = 1777
--
-- Share of Portfolio Unfulfilled Units:
-- 1777 / 3681 * 100 = 48.27%
--
-- Combined Stockout Locations:
-- 9 + 7 + 6 = 22
--
-- Combined Recurring Locations:
-- 15 + 12 + 13 = 40
--
-- Combined Stockout Days:
-- 128 + 109 + 60 = 297
--
-- Combined Reorder Gap Units:
-- 218 + 84 + 27 = 329
--
-- Combined Potential Margin Exposure:
-- 575632.69 + 488275.98 + 459738.32
-- = INR 1523646.99
--
-- Portfolio Exposure Share:
-- 1523646.99 / 3071205.83 * 100
-- = 49.61%
--
-- Combined Illustrative Net Contribution:
-- INR 342820.58
--
-- BUSINESS INTERPRETATION:
-- The first three financially ranked
-- workstreams account for nearly half
-- of October potential gross-margin exposure.
--
-- Review these groups first, subject
-- to operational and customer constraints.
--
-- =========================================================
-- G. P2 - NEXT FIVE WORKSTREAMS
-- =========================================================
--
-- RANK 4:
-- Home Appliances - West
-- Exposure INR: 390149.63
--
-- RANK 5:
-- Home & Living - North
-- Exposure INR: 233934.18
--
-- RANK 6:
-- Sports - South
-- Exposure INR: 202300.55
--
-- RANK 7:
-- Sports - West
-- Exposure INR: 104830.65
--
-- RANK 8:
-- Electronics - South
-- Exposure INR: 97727.32
--
-- P2 WORKSTREAM SUMMARY:
--
-- Workstreams                       : 5
-- Unfulfilled Units                 : 964
-- Stockout Locations                : 22
-- Recurring Stockout Locations      : 65
-- Reorder Gap Units                 : 1475
--
-- Combined Potential Exposure:
-- INR 1028942.33
--
-- Financial Exposure Share:
-- 33.50%
--
-- Combined Illustrative Net Contribution:
-- INR 231512.03
--
-- =========================================================
-- H. P3 - REMAINING TEN WORKSTREAMS
-- =========================================================
--
-- Workstreams                       : 10
-- Unfulfilled Units                 : 940
-- Stockout Locations                : 35
-- Recurring Stockout Locations      : 111
-- Reorder Gap Units                 : 2740
--
-- Combined Potential Exposure:
-- INR 518616.51
--
-- Financial Exposure Share:
-- 16.89%
--
-- Combined Illustrative Net Contribution:
-- INR 116688.71
--
-- IMPORTANT:
-- Lower financial exposure does not
-- necessarily mean lower operational risk.
--
-- Example:
-- Beauty - South has 470 reorder gap units,
-- even though it ranks 16th financially.
--
-- Maintain separate operational exception
-- screening alongside financial ranking.
--
-- =========================================================
-- I. PORTFOLIO PRIORITY CONCENTRATION
-- =========================================================
--
-- PRIORITY    GROUPS    EXPOSURE INR     SHARE
--
-- P1            3       1523646.99      49.61%
-- P2            5       1028942.33      33.50%
-- P3           10        518616.51      16.89%
--
-- TOTAL        18       3071205.83     100.00%
--
-- TOP EIGHT GROUPS:
--
-- P1 + P2 Exposure:
-- 1523646.99 + 1028942.33
-- = INR 2552589.32
--
-- Share of October Exposure:
-- 83.11%
--
-- Top-Eight Unfulfilled Units:
-- 1777 + 964 = 2741
--
-- Unfulfilled Unit Contribution:
-- 2741 / 3681 * 100 = 74.46%
--
-- Top-Eight Stockout Locations:
-- 22 + 22 = 44
--
-- Top-Eight Illustrative Net Contribution:
-- INR 574332.61
--
-- =========================================================
-- J. ILLUSTRATIVE FINANCIAL OPPORTUNITY
-- =========================================================
--
-- Recovery Assumption:
-- 25% of October unfulfilled demand
--
-- Additional Execution Cost:
-- 10% of recovered gross margin
--
-- Formula:
--
-- Potential Margin Exposure
-- * 0.25 * (1 - 0.10)
--
-- = Potential Margin Exposure * 0.225
--
-- Portfolio Opportunity:
-- 3071205.83 * 0.225
-- = INR 691021.31 (rounded)
--
-- P1 Illustrative Contribution:
-- INR 342820.58
--
-- P2 Illustrative Contribution:
-- INR 231512.03
--
-- P3 Illustrative Contribution:
-- INR 116688.71
--
-- IMPORTANT ROUNDING NOTE:
-- Adding independently displayed,
-- rounded group contributions produces
-- INR 691021.32.
--
-- The portfolio figure is calculated
-- using unrounded group values and is
-- INR 691021.31 after final rounding.
--
-- This INR 0.01 presentation difference
-- is not a reconciliation failure.
--
-- Also, these tier-level illustrations
-- are not independent projects with
-- guaranteed additive recoveries.
--
-- =========================================================
-- K. PROPOSED MANAGEMENT EXECUTION FRAMEWORK
-- =========================================================
--
-- STEP 1:
-- Review P1 workstreams and identify
-- their highest-impact shortage SKUs.
--
-- ACCOUNTABLE FUNCTION:
-- Relevant Warehouse Inventory Manager
--
-- STEP 2:
-- Validate demand patterns and historical
-- shortage recurrence.
--
-- SUPPORTING FUNCTION:
-- Demand Planning
--
-- STEP 3:
-- Confirm replenishment feasibility,
-- supplier timing and procurement constraints.
--
-- SUPPORTING FUNCTION:
-- Procurement
--
-- STEP 4:
-- Estimate actual incremental product,
-- transport, handling and implementation costs.
--
-- SUPPORTING FUNCTION:
-- Category Management and Finance
--
-- STEP 5:
-- Obtain approval before changing stock
-- targets or creating purchase orders.
--
-- STEP 6:
-- Track results against October baselines
-- in subsequent reporting months.
--
-- =========================================================
-- L. SUCCESS MEASUREMENT
-- =========================================================
--
-- CORE PORTFOLIO METRICS:
--
-- October Fill Rate:
-- 92.87%
--
-- October Unfulfilled Units:
-- 3681
--
-- October Stockout Locations:
-- 79
--
-- October Potential Margin Exposure:
-- INR 3071205.83
--
-- October Positive-Stock Reorder Gap:
-- 4544 units
--
-- Historical Recurring Stockout Locations:
-- 216
--
-- GROUP-LEVEL KPIs:
--
-- 1. Monthly Fill Rate
-- 2. Monthly Unfulfilled Units
-- 3. Monthly Stockout Locations
-- 4. Monthly Below-Reorder Locations
-- 5. Monthly Reorder Gap Units
-- 6. Monthly Potential Margin Exposure
-- 7. Repeat-Stockout Incidence
-- 8. Recovered Demand, When Measurable
-- 9. Actual Incremental Intervention Cost
-- 10. Realized Gross Contribution, When Verifiable
--
-- No numeric improvement target has
-- been approved by stakeholders.
--
-- Proposed targets should follow
-- feasibility and baseline review.
--
-- =========================================================
-- M. RECOMMENDATION QUALITY ASSURANCE
-- =========================================================
--
-- Reconciliation Checks:
--
-- 01. Action Groups = 18                   PASS
-- 02. SKU-Warehouse Locations = 360       PASS
-- 03. Stockout Locations = 79             PASS
-- 04. Zero-Stock Locations = 79           PASS
-- 05. Below-Reorder Locations = 141       PASS
-- 06. Recurring Locations = 216           PASS
-- 07. Complete Histories = 360            PASS
-- 08. Reorder Gap Units = 4544            PASS
-- 09. Unfulfilled Units = 3681            PASS
-- 10. Potential Margin = INR 3071205.83  PASS
-- 11. Illustrative Contribution =         PASS
--     INR 691021.31
--
-- All 18 recommendation rows returned PASS.
--
-- FINAL SECTION 08.4 QA:
-- PASS
--
-- Note:
-- Reconciliation PASS confirms the
-- computational rules and benchmark totals.
--
-- It does not confirm recommendation
-- effectiveness or management approval.
--
-- =========================================================
-- N. SQL TECHNIQUES USED
-- =========================================================
--
-- HISTORICAL GROUPING:
-- Calculates recurring-stockout months
-- per SKU-warehouse location.
--
-- LEFT JOIN:
-- Connects historical recurring-risk
-- evidence to October financial records.
--
-- GROUP BY category, warehouse:
-- Builds mutually exclusive action groups.
--
-- ROW_NUMBER():
-- Assigns deterministic financial ranks.
--
-- CASE:
-- Assigns proposed priority tiers,
-- action types and monitoring metrics.
--
-- SUM(...) OVER():
-- Reconciles portfolio-wide totals.
--
-- CUMULATIVE WINDOW SUM:
-- Measures financial concentration
-- across the ranked action groups.
--
-- CONCAT():
-- Builds a proposed accountable
-- warehouse-manager role.
--
-- =========================================================
-- O. BUSINESS LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business data.
--
-- 2. Financial exposure is potential,
--    not recorded lost profit.
--
-- 3. Recovery and cost assumptions
--    are illustrative, not forecasts.
--
-- 4. Proposed roles are not confirmed
--    individual owner assignments.
--
-- 5. The prioritization uses financial
--    exposure as its primary ranking.
--
-- 6. Contractual, service-critical and
--    safety-related issues could override
--    the financial ordering.
--
-- 7. Supplier association does not
--    establish supplier-caused shortages.
--
-- 8. Root causes require further
--    operational investigation.
--
-- 9. Reorder gaps do not establish
--    purchase-order quantities.
--
-- 10. Financial recoverability and actual
--     intervention costs are unverified.
--
-- 11. No recommendation has been executed.
--
-- 12. No actual financial benefit or
--     post-intervention KPI improvement
--     has been demonstrated.
--
-- =========================================================
-- FINAL BUSINESS CONCLUSION
-- =========================================================
--
-- The first 3 of 18 category-warehouse
-- groups account for 49.61% of October
-- potential gross-margin exposure.
--
-- The first 8 groups account for 83.11%.
--
-- Management can use the rankings to
-- organize investigations and resource
-- allocation, while separately checking
-- service severity, feasibility and costs.
--
-- Prioritization is evidence-based;
-- the effectiveness of proposed actions
-- remains to be tested.
--
-- =========================================================
-- SECTION 08.4 STATUS:
-- VERIFIED - 18/18 PASS
--
-- NEXT:
-- SECTION 08.5 - FINAL FINANCIAL RECONCILIATION
-- =========================================================
-- =========================================================
-- SECTION 08.5: FINAL FINANCIAL RECONCILIATION & QA
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
-- DATABASE: supply_chain_ai_db
--
-- OCTOBER FINANCIAL PERIOD: 2026-10-01
-- HISTORICAL PERIOD: 2025-11 TO 2026-10
--
-- PURPOSE:
-- Independently rebuild financial calculations
-- from inventory records and test all sections
-- of Script 08 against verified benchmarks.
--
-- EXPECTED:
-- 48 QA checks
-- 47 vertical metric/value output rows
--
-- IMPORTANT:
-- Monetary calculations retain full precision.
-- Rounding is applied only for display.
-- =========================================================


WITH historical_locations AS (

    SELECT
        sku_id,
        warehouse,

        COUNT(DISTINCT reporting_month)
            AS observed_months,

        SUM(
            CASE WHEN stockout_days > 0
                 THEN 1 ELSE 0 END
        ) AS stockout_months

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month BETWEEN
        '2025-11-01' AND '2026-10-01'

    GROUP BY sku_id, warehouse
),

historical_summary AS (

    SELECT
        COUNT(*) AS historical_location_count,

        SUM(
            CASE WHEN observed_months = 12
                 THEN 1 ELSE 0 END
        ) AS complete_history_count,

        SUM(
            CASE WHEN stockout_months >= 2
                 THEN 1 ELSE 0 END
        ) AS historical_recurring_count

    FROM historical_locations
),

-- =========================================================
-- A. REBUILD OCTOBER FINANCIAL LINES
-- =========================================================

october_lines AS (

    SELECT
        sku_id,
        category,
        warehouse,
        supplier_id,

        demand_units,
        fulfilled_units,
        stockout_days,
        unit_selling_price,
        unit_cost,

        CASE
            WHEN stockout_days > 0
            THEN 1 ELSE 0
        END AS stockout_flag,

        CASE
            WHEN closing_stock_units = 0
            THEN 1 ELSE 0
        END AS zero_stock_flag,

        CASE
            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
            THEN 1 ELSE 0
        END AS below_reorder_flag,

        CASE
            WHEN closing_stock_units >= reorder_point_units
            THEN 1 ELSE 0
        END AS healthy_flag,

        CASE
            WHEN closing_stock_units > 0
             AND closing_stock_units < reorder_point_units
            THEN reorder_point_units - closing_stock_units
            ELSE 0
        END AS reorder_gap_units,

        demand_units - fulfilled_units
            AS unfulfilled_units,

        (demand_units - fulfilled_units)
        * unit_selling_price
            AS unmet_sales_inr,

        (demand_units - fulfilled_units)
        * unit_cost
            AS unmet_cost_inr,

        (demand_units - fulfilled_units)
        * (unit_selling_price - unit_cost)
            AS signed_margin_inr,

        (demand_units - fulfilled_units)
        * GREATEST(
            unit_selling_price - unit_cost, 0
        ) AS margin_exposure_inr,

        fulfilled_units
        * (unit_selling_price - unit_cost)
            AS fulfilled_contribution_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'
),

-- =========================================================
-- B. REBUILD OCTOBER PORTFOLIO FINANCIAL BRIDGE
-- =========================================================

portfolio AS (

    SELECT
        COUNT(*) AS location_count,

        COUNT(DISTINCT sku_id) AS sku_count,
        COUNT(DISTINCT warehouse) AS warehouse_count,
        COUNT(DISTINCT category) AS category_count,
        COUNT(DISTINCT supplier_id) AS supplier_count,

        SUM(demand_units) AS demand_total,
        SUM(fulfilled_units) AS fulfilled_total,
        SUM(unfulfilled_units) AS unfulfilled_total,

        SUM(stockout_flag) AS stockout_total,
        SUM(zero_stock_flag) AS zero_total,
        SUM(below_reorder_flag) AS below_total,
        SUM(healthy_flag) AS healthy_total,

        SUM(stockout_days) AS stockout_days_total,
        SUM(reorder_gap_units) AS reorder_gap_total,

        SUM(unmet_sales_inr) AS unmet_sales_total,
        SUM(unmet_cost_inr) AS unmet_cost_total,

        SUM(signed_margin_inr) AS signed_margin_total,

        SUM(margin_exposure_inr) AS margin_total,

        SUM(fulfilled_contribution_inr)
            AS fulfilled_contribution_total

    FROM october_lines
),

-- =========================================================
-- C. REBUILD 3 INDEPENDENT FINANCIAL DIMENSIONS
-- =========================================================

dimension_segments AS (

    SELECT
        'WAREHOUSE' AS dimension_type,
        warehouse AS segment_name,

        COUNT(*) AS segment_locations,
        SUM(stockout_flag) AS segment_stockouts,
        SUM(unfulfilled_units) AS segment_unfulfilled,
        SUM(unmet_sales_inr) AS segment_sales,
        SUM(unmet_cost_inr) AS segment_cost,
        SUM(margin_exposure_inr) AS segment_margin

    FROM october_lines
    GROUP BY warehouse

    UNION ALL

    SELECT
        'CATEGORY',
        category,
        COUNT(*),
        SUM(stockout_flag),
        SUM(unfulfilled_units),
        SUM(unmet_sales_inr),
        SUM(unmet_cost_inr),
        SUM(margin_exposure_inr)

    FROM october_lines
    GROUP BY category

    UNION ALL

    SELECT
        'SUPPLIER',
        supplier_id,
        COUNT(*),
        SUM(stockout_flag),
        SUM(unfulfilled_units),
        SUM(unmet_sales_inr),
        SUM(unmet_cost_inr),
        SUM(margin_exposure_inr)

    FROM october_lines
    GROUP BY supplier_id
),

dimension_rankings AS (

    SELECT
        d.*,

        ROW_NUMBER() OVER (
            PARTITION BY dimension_type
            ORDER BY segment_margin DESC, segment_name
        ) AS financial_rank

    FROM dimension_segments d
),

dimension_rollup AS (

    SELECT
        dimension_type,

        COUNT(*) AS segment_count,

        SUM(segment_locations) AS dim_locations,
        SUM(segment_stockouts) AS dim_stockouts,
        SUM(segment_unfulfilled) AS dim_unfulfilled,

        SUM(segment_sales) AS dim_sales,
        SUM(segment_cost) AS dim_cost,
        SUM(segment_margin) AS dim_margin,

        MAX(
            CASE WHEN financial_rank = 1
                 THEN segment_name ELSE NULL END
        ) AS leading_segment,

        SUM(
            CASE WHEN financial_rank <= 2
                 THEN segment_margin ELSE 0 END
        ) AS top_two_exposure

    FROM dimension_rankings

    GROUP BY dimension_type
),

dimension_summary AS (

    SELECT
        COUNT(*) AS dimension_views,

        SUM(segment_count) AS total_dimension_groups,

        SUM(
            CASE
                WHEN dimension_type = 'WAREHOUSE'
                     AND segment_count = 3
                THEN 1

                WHEN dimension_type = 'CATEGORY'
                     AND segment_count = 6
                THEN 1

                WHEN dimension_type = 'SUPPLIER'
                     AND segment_count = 12
                THEN 1

                ELSE 0
            END
        ) AS correctly_sized_dimensions,

        SUM(
            CASE WHEN dim_locations = 360
                 THEN 1 ELSE 0 END
        ) AS dimensions_matching_locations,

        SUM(
            CASE WHEN dim_stockouts = 79
                 THEN 1 ELSE 0 END
        ) AS dimensions_matching_stockouts,

        SUM(
            CASE WHEN dim_unfulfilled = 3681
                 THEN 1 ELSE 0 END
        ) AS dimensions_matching_unfulfilled,

        SUM(
            CASE WHEN ABS(dim_sales - 9356605.50) < 0.01
                 THEN 1 ELSE 0 END
        ) AS dimensions_matching_sales,

        SUM(
            CASE WHEN ABS(dim_cost - 6285399.67) < 0.01
                 THEN 1 ELSE 0 END
        ) AS dimensions_matching_cost,

        SUM(
            CASE WHEN ABS(dim_margin - 3071205.83) < 0.01
                 THEN 1 ELSE 0 END
        ) AS dimensions_matching_margin,

        MAX(
            CASE WHEN dimension_type = 'WAREHOUSE'
                 THEN leading_segment ELSE NULL END
        ) AS top_warehouse,

        MAX(
            CASE WHEN dimension_type = 'CATEGORY'
                 THEN leading_segment ELSE NULL END
        ) AS top_category,

        MAX(
            CASE WHEN dimension_type = 'SUPPLIER'
                 THEN leading_segment ELSE NULL END
        ) AS top_supplier,

        MAX(
            CASE WHEN dimension_type = 'CATEGORY'
                 THEN top_two_exposure ELSE NULL END
        ) AS top_two_category_exposure

    FROM dimension_rollup
),

-- =========================================================
-- D. REBUILD THE 18 RECOMMENDATION GROUPS
-- =========================================================

recommendation_evidence AS (

    SELECT
        o.*,

        CASE
            WHEN h.stockout_months >= 2
            THEN 1 ELSE 0
        END AS recurring_flag,

        CASE
            WHEN h.observed_months = 12
            THEN 1 ELSE 0
        END AS complete_history_flag

    FROM october_lines o

    LEFT JOIN historical_locations h
        ON o.sku_id = h.sku_id
       AND o.warehouse = h.warehouse
),

action_groups AS (

    SELECT
        category,
        warehouse,

        COUNT(*) AS group_locations,

        SUM(stockout_flag) AS group_stockouts,
        SUM(stockout_days) AS group_stockout_days,

        SUM(below_reorder_flag) AS group_below_reorder,
        SUM(reorder_gap_units) AS group_reorder_gap,

        SUM(recurring_flag) AS group_recurring,
        SUM(complete_history_flag) AS group_complete_history,

        SUM(unfulfilled_units) AS group_unfulfilled,
        SUM(margin_exposure_inr) AS group_margin

    FROM recommendation_evidence

    GROUP BY category, warehouse
),

action_rankings AS (

    SELECT
        a.*,

        ROW_NUMBER() OVER (
            ORDER BY
                group_margin DESC,
                group_unfulfilled DESC,
                category,
                warehouse
        ) AS action_rank

    FROM action_groups a
),

action_summary AS (

    SELECT
        COUNT(*) AS action_group_count,

        SUM(
            CASE WHEN group_locations <> 20
                 THEN 1 ELSE 0 END
        ) AS abnormal_group_sizes,

        SUM(group_locations) AS action_locations,
        SUM(group_stockouts) AS action_stockouts,
        SUM(group_stockout_days) AS action_stockout_days,
        SUM(group_below_reorder) AS action_below_reorder,
        SUM(group_reorder_gap) AS action_reorder_gap,

        SUM(group_recurring) AS action_recurring,
        SUM(group_complete_history) AS action_complete_history,

        SUM(group_unfulfilled) AS action_unfulfilled,
        SUM(group_margin) AS action_margin,

        -- P1: Financial ranks 1-3
        SUM(
            CASE WHEN action_rank <= 3
                 THEN 1 ELSE 0 END
        ) AS p1_group_count,

        SUM(
            CASE WHEN action_rank <= 3
                 THEN group_margin ELSE 0 END
        ) AS p1_exposure,

        SUM(
            CASE WHEN action_rank <= 3
                 THEN group_unfulfilled ELSE 0 END
        ) AS p1_unfulfilled,

        -- P2: Financial ranks 4-8
        SUM(
            CASE WHEN action_rank BETWEEN 4 AND 8
                 THEN 1 ELSE 0 END
        ) AS p2_group_count,

        SUM(
            CASE WHEN action_rank BETWEEN 4 AND 8
                 THEN group_margin ELSE 0 END
        ) AS p2_exposure,

        SUM(
            CASE WHEN action_rank BETWEEN 4 AND 8
                 THEN group_unfulfilled ELSE 0 END
        ) AS p2_unfulfilled,

        -- P3: Financial ranks 9-18
        SUM(
            CASE WHEN action_rank >= 9
                 THEN 1 ELSE 0 END
        ) AS p3_group_count,

        SUM(
            CASE WHEN action_rank >= 9
                 THEN group_margin ELSE 0 END
        ) AS p3_exposure,

        SUM(
            CASE WHEN action_rank >= 9
                 THEN group_unfulfilled ELSE 0 END
        ) AS p3_unfulfilled,

        -- First eight workstreams
        SUM(
            CASE WHEN action_rank <= 8
                 THEN group_margin ELSE 0 END
        ) AS top_eight_exposure,

        SUM(
            CASE WHEN action_rank <= 8
                 THEN group_unfulfilled ELSE 0 END
        ) AS top_eight_unfulfilled

    FROM action_rankings
),

-- =========================================================
-- E. REBUILD NINE RECOVERY/COST SCENARIOS
-- =========================================================

recovery_rates AS (

    SELECT CAST(0.10 AS DECIMAL(4,2)) AS recovery_rate
    UNION ALL SELECT CAST(0.25 AS DECIMAL(4,2))
    UNION ALL SELECT CAST(0.50 AS DECIMAL(4,2))
),

execution_cost_rates AS (

    SELECT CAST(0.00 AS DECIMAL(4,2)) AS cost_rate
    UNION ALL SELECT CAST(0.10 AS DECIMAL(4,2))
    UNION ALL SELECT CAST(0.20 AS DECIMAL(4,2))
),

scenario_rows AS (

    SELECT
        r.recovery_rate,
        c.cost_rate,

        p.unfulfilled_total * r.recovery_rate
            AS recovered_units,

        p.unmet_sales_total * r.recovery_rate
            AS recovered_sales,

        p.unmet_cost_total * r.recovery_rate
            AS recovered_cost,

        p.margin_total * r.recovery_rate
            AS recovered_margin,

        p.margin_total * (1 - r.recovery_rate)
            AS remaining_margin,

        p.margin_total * r.recovery_rate * c.cost_rate
            AS additional_cost,

        p.margin_total * r.recovery_rate * (1 - c.cost_rate)
            AS net_incremental_contribution,

        (
            p.fulfilled_total
            + p.unfulfilled_total * r.recovery_rate
        ) * 100.0 / NULLIF(p.demand_total, 0)
            AS modeled_fill_rate

    FROM portfolio p

    CROSS JOIN recovery_rates r

    CROSS JOIN execution_cost_rates c
),

scenario_summary AS (

    SELECT
        COUNT(*) AS scenario_count,

        SUM(
            CASE

                WHEN ABS(
                    recovered_sales
                    - recovered_cost
                    - recovered_margin
                ) < 0.01

                AND ABS(
                    recovered_margin
                    + remaining_margin
                    - 3071205.83
                ) < 0.01

                AND ABS(
                    recovered_margin
                    - additional_cost
                    - net_incremental_contribution
                ) < 0.01

                AND recovery_rate BETWEEN 0 AND 1
                AND cost_rate BETWEEN 0 AND 1

                THEN 1 ELSE 0

            END
        ) AS scenario_pass_count,

        MAX(
            CASE
                WHEN recovery_rate = 0.25
                 AND cost_rate = 0.10
                THEN net_incremental_contribution
                ELSE NULL
            END
        ) AS middle_scenario_contribution,

        MAX(
            CASE
                WHEN recovery_rate = 0.25
                 AND cost_rate = 0.10
                THEN modeled_fill_rate
                ELSE NULL
            END
        ) AS middle_scenario_fill_rate,

        MAX(
            CASE
                WHEN recovery_rate = 0.50
                 AND cost_rate = 0.20
                THEN net_incremental_contribution
                ELSE NULL
            END
        ) AS high_recovery_high_cost_contribution

    FROM scenario_rows
),

-- =========================================================
-- F. COLLECT ALL FINANCIAL QA MEASURES
-- =========================================================

all_metrics AS (

    SELECT
        p.*,
        h.*,
        d.*,
        a.*,
        s.*

    FROM portfolio p

    CROSS JOIN historical_summary h
    CROSS JOIN dimension_summary d
    CROSS JOIN action_summary a
    CROSS JOIN scenario_summary s
),

-- =========================================================
-- G. EXPLICIT FINANCIAL QA RULES
-- FAILED = 0 MEANS PASS
-- FAILED = 1 MEANS FAIL
-- =========================================================

validation_rules AS (

    SELECT
        1 AS id,
        'October location count' AS rule_name,
        IF(location_count = 360, 0, 1) AS failed
    FROM all_metrics

    UNION ALL SELECT 2, 'Distinct SKU count',
        IF(sku_count = 120, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 3, 'Distinct warehouse count',
        IF(warehouse_count = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 4, 'Distinct category count',
        IF(category_count = 6, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 5, 'Distinct supplier count',
        IF(supplier_count = 12, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 6, 'October demand',
        IF(demand_total = 51603, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 7, 'October fulfilled units',
        IF(fulfilled_total = 47922, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 8, 'October unfulfilled units',
        IF(unfulfilled_total = 3681, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 9, 'Demand and fulfillment balance',
        IF(demand_total = fulfilled_total
           + unfulfilled_total, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 10, 'October stockout locations',
        IF(stockout_total = 79, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 11, 'October zero-stock locations',
        IF(zero_total = 79, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 12, 'October below-reorder locations',
        IF(below_total = 141, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 13, 'October healthy locations',
        IF(healthy_total = 140, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 14, 'Inventory classification balance',
        IF(zero_total + below_total + healthy_total
           = location_count, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 15, 'October stockout days',
        IF(stockout_days_total = 751, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 16, 'October reorder gap',
        IF(reorder_gap_total = 4544, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 17, 'Potential unmet sales value',
        IF(ABS(unmet_sales_total - 9356605.50) < 0.01,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 18, 'Associated unmet product cost',
        IF(ABS(unmet_cost_total - 6285399.67) < 0.01,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 19, 'Potential margin exposure',
        IF(ABS(margin_total - 3071205.83) < 0.01,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 20, 'Sales-cost-signed margin bridge',
        IF(ABS(
            unmet_sales_total
            - unmet_cost_total
            - signed_margin_total
        ) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 21, 'Signed versus nonnegative margin',
        IF(ABS(
            signed_margin_total - margin_total
        ) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 22, 'Fulfilled gross contribution',
        IF(ABS(
            fulfilled_contribution_total - 44864064.22
        ) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 23, 'Historical location population',
        IF(historical_location_count = 360, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 24, 'Complete historical locations',
        IF(complete_history_count = 360, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 25, 'Recurring stockout locations',
        IF(historical_recurring_count = 216, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 26, 'Three financial dimensions',
        IF(dimension_views = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 27, 'Twenty-one dimension segments',
        IF(total_dimension_groups = 21, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 28, 'Dimension group structure',
        IF(correctly_sized_dimensions = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 29, 'Dimension location reconciliation',
        IF(dimensions_matching_locations = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 30, 'Dimension stockout reconciliation',
        IF(dimensions_matching_stockouts = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 31, 'Dimension unmet-demand reconciliation',
        IF(dimensions_matching_unfulfilled = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 32, 'Dimension unmet-sales reconciliation',
        IF(dimensions_matching_sales = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 33, 'Dimension product-cost reconciliation',
        IF(dimensions_matching_cost = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 34, 'Dimension margin reconciliation',
        IF(dimensions_matching_margin = 3, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 35, 'Highest exposure warehouse',
        IF(top_warehouse = 'West', 0, 1)
    FROM all_metrics

    UNION ALL SELECT 36, 'Highest exposure category',
        IF(top_category = 'Home & Living', 0, 1)
    FROM all_metrics

    UNION ALL SELECT 37, 'Highest exposure supplier portfolio',
        IF(top_supplier = 'SUP005', 0, 1)
    FROM all_metrics

    UNION ALL SELECT 38, 'Top-two category concentration',
        IF(ABS(
            top_two_category_exposure - 2211104.32
        ) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 39, 'Eighteen recommendation groups',
        IF(action_group_count = 18, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 40, 'Recommendation group location structure',
        IF(abnormal_group_sizes = 0
           AND action_locations = 360, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 41, 'Action stockout and recurrence totals',
        IF(action_stockouts = 79
           AND action_stockout_days = 751
           AND action_recurring = 216
           AND action_complete_history = 360, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 42, 'Action reorder-risk totals',
        IF(action_below_reorder = 141
           AND action_reorder_gap = 4544, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 43, 'Action unmet and financial totals',
        IF(action_unfulfilled = 3681
           AND ABS(action_margin - 3071205.83) < 0.01,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 44, 'P1 P2 P3 tier reconciliation',
        IF(p1_group_count = 3
           AND p2_group_count = 5
           AND p3_group_count = 10
           AND ABS(p1_exposure - 1523646.99) < 0.01
           AND ABS(p2_exposure - 1028942.33) < 0.01
           AND ABS(p3_exposure - 518616.51) < 0.01,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 45, 'Top-eight financial concentration',
        IF(ABS(top_eight_exposure - 2552589.32) < 0.01
           AND top_eight_unfulfilled = 2741,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 46, 'Nine recovery scenarios',
        IF(scenario_count = 9
           AND scenario_pass_count = 9,
           0, 1)
    FROM all_metrics

    UNION ALL SELECT 47, 'Middle scenario financial and fill-rate check',
        IF(ABS(
            middle_scenario_contribution - 691021.31
        ) < 0.01
           AND ABS(
            middle_scenario_fill_rate - 94.65
        ) < 0.01, 0, 1)
    FROM all_metrics

    UNION ALL SELECT 48, 'Priority contribution and scenario reconciliation',
        IF(ABS(
            (p1_exposure + p2_exposure + p3_exposure)
            * 0.25 * 0.90
            - middle_scenario_contribution
        ) < 0.01

           AND ROUND(p1_exposure * 0.225, 2)
               = 342820.57

           AND ROUND(p2_exposure * 0.225, 2)
               = 231512.02

           AND ROUND(p3_exposure * 0.225, 2)
               = 116688.71

           AND ROUND(top_eight_exposure * 0.225, 2)
               = 574332.60

           AND ABS(
               high_recovery_high_cost_contribution
               - 1228482.33
           ) < 0.01,

           0, 1)
    FROM all_metrics
),

-- =========================================================
-- H. OVERALL QA RESULT
-- =========================================================

qa_summary AS (

    SELECT
        COUNT(*) AS checks_executed,

        SUM(failed) AS failed_checks,

        COALESCE(
            GROUP_CONCAT(
                CASE WHEN failed = 1
                     THEN rule_name ELSE NULL END
                ORDER BY id SEPARATOR '; '
            ),
            'None'
        ) AS failed_rule_names

    FROM validation_rules
),

-- =========================================================
-- I. VERTICAL METRIC | VALUE OUTPUT
-- =========================================================

report_rows AS (

    SELECT 1 AS seq,
        'Reporting Month' AS metric,
        '2026-10' AS value

    UNION ALL SELECT 2, 'October Inventory Locations',
        CAST(location_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 3, 'Distinct SKUs',
        CAST(sku_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 4, 'Distinct Warehouses',
        CAST(warehouse_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 5, 'Distinct Categories',
        CAST(category_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 6, 'Distinct Suppliers',
        CAST(supplier_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 7, 'October Demand Units',
        CAST(demand_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 8, 'October Fulfilled Units',
        CAST(fulfilled_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 9, 'October Unfulfilled Units',
        CAST(unfulfilled_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 10, 'October Fill Rate (%)',
        CAST(
            ROUND(fulfilled_total * 100.0 /
                  NULLIF(demand_total, 0), 2)
            AS CHAR
        )
    FROM all_metrics

    UNION ALL SELECT 11, 'October Zero-Stock Locations',
        CAST(zero_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 12, 'October Below-Reorder Locations',
        CAST(below_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 13, 'October Healthy Locations',
        CAST(healthy_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 14, 'October Stockout Locations',
        CAST(stockout_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 15, 'October Stockout Days',
        CAST(stockout_days_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 16, 'October Reorder Gap Units',
        CAST(reorder_gap_total AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 17, 'Potential Unmet Sales (INR)',
        CAST(ROUND(unmet_sales_total, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 18, 'Associated Product Cost (INR)',
        CAST(ROUND(unmet_cost_total, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 19, 'Signed Potential Margin (INR)',
        CAST(ROUND(signed_margin_total, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 20, 'Potential Margin Exposure (INR)',
        CAST(ROUND(margin_total, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 21, 'Financial Bridge Difference (INR)',
        CAST(
            ROUND(unmet_sales_total - unmet_cost_total
                  - margin_total, 2)
            AS CHAR
        )
    FROM all_metrics

    UNION ALL SELECT 22, 'Fulfilled Gross Contribution (INR)',
        CAST(ROUND(fulfilled_contribution_total, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 23, 'Historical SKU-Warehouse Locations',
        CAST(historical_location_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 24, 'Complete Historical Locations',
        CAST(complete_history_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 25, 'Recurring Stockout Locations',
        CAST(historical_recurring_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 26, 'Financial Dimension Groups',
        CAST(total_dimension_groups AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 27, 'Dimensions Matching Margin Total',
        CAST(dimensions_matching_margin AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 28, 'Top Financial Warehouse',
        top_warehouse
    FROM all_metrics

    UNION ALL SELECT 29, 'Top Financial Category',
        top_category
    FROM all_metrics

    UNION ALL SELECT 30, 'Top Financial Supplier Portfolio',
        top_supplier
    FROM all_metrics

    UNION ALL SELECT 31, 'Top-Two Category Exposure (INR)',
        CAST(ROUND(top_two_category_exposure, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 32, 'Recommendation Action Groups',
        CAST(action_group_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 33, 'P1 Potential Exposure (INR)',
        CAST(ROUND(p1_exposure, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 34, 'P2 Potential Exposure (INR)',
        CAST(ROUND(p2_exposure, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 35, 'P3 Potential Exposure (INR)',
        CAST(ROUND(p3_exposure, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 36, 'Top-Eight Exposure (INR)',
        CAST(ROUND(top_eight_exposure, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 37, 'P1 Scenario Net Contribution (INR)',
        CAST(ROUND(p1_exposure * 0.225, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 38, 'P2 Scenario Net Contribution (INR)',
        CAST(ROUND(p2_exposure * 0.225, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 39, 'P3 Scenario Net Contribution (INR)',
        CAST(ROUND(p3_exposure * 0.225, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 40, 'Top-Eight Scenario Contribution (INR)',
        CAST(ROUND(top_eight_exposure * 0.225, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 41, 'Portfolio Middle-Scenario Contribution (INR)',
        CAST(ROUND(middle_scenario_contribution, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 42, 'Recovery Scenario Rows',
        CAST(scenario_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 43, 'Recovery Scenarios Passed',
        CAST(scenario_pass_count AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 44, 'Middle-Scenario Fill Rate (%)',
        CAST(ROUND(middle_scenario_fill_rate, 2) AS CHAR)
    FROM all_metrics

    UNION ALL SELECT 45, 'Financial QA Rules Executed',
        CAST(checks_executed AS CHAR)
    FROM qa_summary

    UNION ALL SELECT 46, 'Failed Financial QA Rules',
        CAST(failed_checks AS CHAR)
    FROM qa_summary

    UNION ALL SELECT 47, 'Overall Financial QA Status',
        CASE
            WHEN checks_executed = 48
             AND failed_checks = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM qa_summary
)

-- =========================================================
-- FINAL FINANCIAL QA OUTPUT
-- =========================================================

SELECT
    metric,
    value

FROM report_rows

ORDER BY seq;
-- =========================================================
-- SECTION 08.5: VERIFIED FINAL FINANCIAL
--               RECONCILIATION & QUALITY ASSURANCE
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
-- REPORTING MONTH:
-- October 2026
--
-- HISTORICAL REFERENCE:
-- November 2025 through October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- FINAL VALIDATION STATUS:
-- PASS
--
-- QA Report Rows Returned       : 47
-- QA Rules Executed             : 48
-- Rules Passed                  : 48
-- Rules Failed                  : 0
--
-- OVERALL FINANCIAL QA STATUS: PASS
--
-- =========================================================
-- A. OCTOBER OPERATIONAL BASELINE
-- =========================================================
--
-- Inventory Locations              : 360
-- Distinct SKUs                     : 120
-- Distinct Warehouses              : 3
-- Distinct Categories              : 6
-- Distinct Suppliers               : 12
--
-- Total Demand Units               : 51603
-- Total Fulfilled Units            : 47922
-- Total Unfulfilled Units          : 3681
--
-- Fill Rate                        : 92.87%
--
-- Demand Reconciliation:
-- 51603 - 47922 = 3681
--
-- Zero-Stock Locations             : 79
-- Below-Reorder Locations          : 141
-- Healthy Locations                : 140
--
-- Classification Reconciliation:
-- 79 + 141 + 140 = 360
--
-- Recorded Stockout Locations      : 79
-- Recorded Stockout Days           : 751
-- Reorder Gap Units                : 4544
--
-- OPERATIONAL RECONCILIATION: PASS
--
-- =========================================================
-- B. FINANCIAL IMPACT BRIDGE
-- =========================================================
--
-- Potential Unmet Sales Value:
-- INR 9356605.50
--
-- Associated Product Cost:
-- INR 6285399.67
--
-- Signed Potential Gross Margin:
-- INR 3071205.83
--
-- Nonnegative Potential Margin Exposure:
-- INR 3071205.83
--
-- Financial Bridge:
-- 9356605.50 - 6285399.67
-- = 3071205.83
--
-- Financial Bridge Difference:
-- INR 0.00
--
-- Modeled Fulfilled Gross Contribution:
-- INR 44864064.22
--
-- FINANCIAL BRIDGE RECONCILIATION: PASS
--
-- IMPORTANT:
-- Potential selling value is not confirmed
-- lost accounting revenue.
--
-- Potential gross-margin exposure is not
-- confirmed lost or recoverable profit.
--
-- =========================================================
-- C. HISTORICAL INVENTORY RISK
-- =========================================================
--
-- Historical SKU-Warehouse Locations:
-- 360
--
-- Locations With Complete 12-Month History:
-- 360
--
-- Locations With Repeated Stockouts:
-- 216
--
-- Recurring Location Rate:
-- 216 / 360 * 100 = 60.00%
--
-- Recurring means stockouts occurred
-- in at least two different months.
--
-- HISTORICAL RECONCILIATION: PASS
--
-- =========================================================
-- D. SECTION 08.2 FINANCIAL DIMENSIONS
-- =========================================================
--
-- Warehouse Groups                 : 3
-- Category Groups                  : 6
-- Supplier Groups                  : 12
--
-- Total Dimension Groups:
-- 3 + 6 + 12 = 21
--
-- Dimensions Matching Portfolio Margin:
-- 3
--
-- Each dimension independently reconciles
-- to the same portfolio potential margin:
-- INR 3071205.83
--
-- HIGHEST FINANCIAL EXPOSURE:
--
-- Warehouse:
-- West
--
-- Category:
-- Home & Living
--
-- Supplier-Associated Portfolio:
-- SUP005
--
-- Top Two Categories:
-- Home & Living + Home Appliances
--
-- Combined Potential Exposure:
-- INR 2211104.32
--
-- Share of Total Exposure:
-- 71.99%
--
-- DIMENSION RECONCILIATION: PASS
--
-- IMPORTANT:
-- Warehouse, category and supplier views
-- overlap in the source inventory data.
--
-- Their financial totals must NOT be added
-- together as separate opportunities.
--
-- =========================================================
-- E. SECTION 08.3 RECOVERY SCENARIOS
-- =========================================================
--
-- Recovery Assumptions:
-- 10%, 25%, 50%
--
-- Incremental Execution Cost Assumptions:
-- 0%, 10%, 20% of recovered gross margin
--
-- Total Scenario Combinations:
-- 3 x 3 = 9
--
-- Scenarios Passed:
-- 9 of 9
--
-- Scenarios Failed:
-- 0
--
-- MIDDLE ILLUSTRATIVE CASE:
--
-- Recovery Assumption:
-- 25%
--
-- Extra Execution Cost Assumption:
-- 10% of recovered gross margin
--
-- Modeled Fill Rate:
-- 94.65%
--
-- Modeled Net Incremental Contribution:
-- INR 691021.31
--
-- HIGH RECOVERY, HIGH COST CASE:
--
-- Recovery Assumption:
-- 50%
--
-- Extra Execution Cost:
-- 20%
--
-- Modeled Net Incremental Contribution:
-- INR 1228482.33
--
-- SCENARIO RECONCILIATION: PASS
--
-- IMPORTANT:
-- Scenario assumptions are not
-- forecasts or measured outcomes.
--
-- =========================================================
-- F. SECTION 08.4 MANAGEMENT WORKSTREAMS
-- =========================================================
--
-- Product Categories              : 6
-- Warehouses                      : 3
--
-- Total Category-Warehouse Groups:
-- 18
--
-- These groups are mutually exclusive
-- at the October SKU-warehouse grain.
--
-- P1: FIRST REVIEW
-- Financial Ranks 1-3
--
-- Groups                         : 3
-- Potential Exposure INR         : 1523646.99
-- Financial Share                : 49.61%
--
-- P2: NEXT WAVE
-- Financial Ranks 4-8
--
-- Groups                         : 5
-- Potential Exposure INR         : 1028942.33
-- Financial Share                : 33.50%
--
-- P3: SELECTIVE REVIEW
-- Financial Ranks 9-18
--
-- Groups                         : 10
-- Potential Exposure INR         : 518616.51
-- Financial Share                : 16.89%
--
-- TOTAL:
--
-- Groups                         : 18
-- Potential Exposure INR         : 3071205.83
-- Financial Share                : 100.00%
--
-- TOP EIGHT WORKSTREAMS:
--
-- Combined Exposure INR:
-- 2552589.32
--
-- Portfolio Exposure Share:
-- 83.11%
--
-- Financial Workstream Reconciliation:
-- PASS
--
-- =========================================================
-- G. CORRECTED ILLUSTRATIVE CONTRIBUTIONS
-- =========================================================
--
-- Financial Scenario Assumption:
-- 25% recovery x 90% margin retention
--
-- Formula:
-- Original Potential Margin x 0.225
--
-- P1 Contribution:
--
-- 1523646.99 x 0.225
-- = 342820.57275
--
-- Rounded:
-- INR 342820.57
--
-- P2 Contribution:
--
-- 1028942.33 x 0.225
-- = 231512.02425
--
-- Rounded:
-- INR 231512.02
--
-- P3 Contribution:
--
-- 518616.51 x 0.225
-- = 116688.71475
--
-- Rounded:
-- INR 116688.71
--
-- TOP EIGHT CONTRIBUTION:
--
-- 2552589.32 x 0.225
-- = 574332.59700
--
-- Rounded:
-- INR 574332.60
--
-- PORTFOLIO CONTRIBUTION:
--
-- 3071205.83 x 0.225
-- = 691021.31175
--
-- Rounded:
-- INR 691021.31
--
-- ROUNDING POLICY:
--
-- Calculate using full precision.
-- Round monetary values once for reporting.
--
-- Adding separately rounded subtotals
-- may differ by INR 0.01 from the
-- independently rounded portfolio total.
--
-- This is a presentation effect,
-- not a reconciliation failure.
--
-- =========================================================
-- H. FINAL 48 QA VALIDATION RULES
-- =========================================================
--
-- SOURCE AND OPERATIONAL CHECKS:
--
-- 01. October Location Count              PASS
-- 02. Distinct SKU Count                  PASS
-- 03. Distinct Warehouse Count            PASS
-- 04. Distinct Category Count             PASS
-- 05. Distinct Supplier Count             PASS
-- 06. October Demand                      PASS
-- 07. October Fulfilled Units             PASS
-- 08. October Unfulfilled Units           PASS
-- 09. Demand-Fulfillment Balance          PASS
-- 10. October Stockout Locations          PASS
-- 11. October Zero-Stock Locations        PASS
-- 12. October Below-Reorder Locations     PASS
-- 13. October Healthy Locations           PASS
-- 14. Inventory Classification Balance    PASS
-- 15. October Stockout Days               PASS
-- 16. October Reorder Gap                 PASS
--
-- FINANCIAL BRIDGE CHECKS:
--
-- 17. Potential Unmet Sales Value         PASS
-- 18. Associated Product Cost            PASS
-- 19. Potential Margin Exposure          PASS
-- 20. Sales-Cost-Signed Margin Bridge     PASS
-- 21. Signed vs Nonnegative Margin        PASS
-- 22. Fulfilled Gross Contribution       PASS
--
-- HISTORICAL RISK CHECKS:
--
-- 23. Historical Location Population      PASS
-- 24. Complete Historical Locations       PASS
-- 25. Recurring Stockout Locations        PASS
--
-- FINANCIAL DIMENSION CHECKS:
--
-- 26. Three Financial Dimensions          PASS
-- 27. Twenty-One Dimension Segments       PASS
-- 28. Dimension Group Structure           PASS
-- 29. Dimension Location Reconciliation   PASS
-- 30. Dimension Stockout Reconciliation   PASS
-- 31. Dimension Unmet-Demand Balance      PASS
-- 32. Dimension Unmet-Sales Balance       PASS
-- 33. Dimension Product-Cost Balance      PASS
-- 34. Dimension Margin Balance            PASS
-- 35. Highest Exposure Warehouse          PASS
-- 36. Highest Exposure Category           PASS
-- 37. Highest Exposure Supplier Portfolio PASS
-- 38. Top-Two Category Concentration      PASS
--
-- MANAGEMENT ACTION CHECKS:
--
-- 39. Eighteen Recommendation Groups      PASS
-- 40. Group Location Structure            PASS
-- 41. Action Stockout and Recurrence      PASS
-- 42. Action Reorder-Risk Totals          PASS
-- 43. Action Unmet and Financial Totals   PASS
-- 44. P1/P2/P3 Tier Reconciliation        PASS
-- 45. Top-Eight Financial Concentration   PASS
--
-- SCENARIO CHECKS:
--
-- 46. Nine Recovery Scenarios             PASS
-- 47. Middle Scenario Financial/Fill QA  PASS
-- 48. Tier Contribution/Scenario Balance  PASS
--
-- TOTAL QA RULES: 48
-- PASSED: 48
-- FAILED: 0
--
-- =========================================================
-- I. FINAL MANAGEMENT FINDINGS
-- =========================================================
--
-- 1. October unmet demand totaled
--    3681 units.
--
-- 2. Associated potential gross-margin
--    exposure was INR 3071205.83.
--
-- 3. West was the highest-exposure warehouse.
--
-- 4. Home & Living was the highest-exposure
--    product category.
--
-- 5. SUP005 had the largest associated
--    supplier-portfolio financial exposure.
--
-- 6. Home & Living and Home Appliances
--    represented 71.99% of potential exposure.
--
-- 7. The first three category-warehouse
--    groups represented 49.61% of exposure.
--
-- 8. The first eight groups represented
--    83.11% of exposure.
--
-- 9. The 25% recovery and 10% extra-cost
--    scenario yielded an illustrative
--    net incremental contribution of
--    INR 691021.31.
--
-- 10. Management should validate shortage
--     causes, customer recoverability,
--     stock feasibility and actual costs
--     before approving interventions.
--
-- =========================================================
-- J. LIMITATIONS AND NEXT STEPS
-- =========================================================
--
-- 1. This is a synthetic business scenario.
--
-- 2. Financial values are modeled from
--    recorded quantities and unit prices.
--
-- 3. Potential exposure is not confirmed
--    lost accounting revenue or profit.
--
-- 4. Recovery and cost percentages are
--    illustrative assumptions, not forecasts.
--
-- 5. Proposed recommendations have not
--    been operationally implemented.
--
-- 6. Proposed owners are role assignments
--    for planning, not confirmed individuals.
--
-- 7. Supplier association does not establish
--    supplier-caused shortages.
--
-- 8. Financially lower-ranked groups may
--    still have service-critical risks.
--
-- 9. The audit validates internal SQL
--    calculations against project benchmarks.
--
-- 10. Independent reconciliation against
--     the cleaned CSV/Python source remains
--     pending in Script 09.
--
-- =========================================================
-- VERIFIED SECTION STATUS
-- =========================================================
--
-- 08.1 Financial Impact Bridge:
-- PASS
--
-- 08.2 Financial Concentration:
-- PASS
--
-- 08.3 Recovery Sensitivity:
-- PASS
--
-- 08.4 Management Recommendations:
-- PASS
--
-- 08.5 Final Financial QA:
-- 48/48 PASS
--
-- =========================================================
-- FINAL SCRIPT 08 STATUS:
-- FINANCIAL ANALYSIS AND DATABASE QA COMPLETE
--
-- NEXT SCRIPT:
-- 09_reconciliation.sql
-- =========================================================