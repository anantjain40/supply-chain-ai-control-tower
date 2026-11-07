-- =========================================================
-- PROJECT 02: SUPPLY CHAIN AI CONTROL TOWER
-- SCRIPT 06: SUPPLIER PERFORMANCE ANALYSIS
-- =========================================================
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- SOURCE DATABASE:
-- supply_chain_ai_db
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- BUSINESS OBJECTIVE:
-- Evaluate supplier delivery reliability,
-- lead-time performance and potential
-- relationships with inventory availability.
--
-- SCRIPT SECTIONS:
-- 06.1 October Supplier KPI Scorecard
-- 06.2 Reliability Rankings & Contribution
-- 06.3 Historical Supplier Performance
-- 06.4 Supplier-Inventory Risk Analysis & QA
--
-- IMPORTANT:
-- Missing delivery outcomes remain unknown.
-- Lead-time calculations must be weighted.
-- Correlation does not establish causation.
-- =========================================================


-- =========================================================
-- SECTION 06.1: OCTOBER SUPPLIER KPI SCORECARD
-- =========================================================
--
-- BUSINESS QUESTION:
-- How reliably did each supplier deliver during
-- October 2026?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- GRAIN:
-- One row per supplier for October 2026.
--
-- EXPECTED:
-- 12 supplier rows.
--
-- METRICS:
-- 1. Distinct SKUs Supported
-- 2. SKU-Warehouse Records
-- 3. Total Recorded Delivery Events
-- 4. Eligible OTD Delivery Events
-- 5. On-Time Delivery Events
-- 6. Late Delivery Events
-- 7. Unknown OTD Delivery Events
-- 8. Supplier OTD Rate
-- 9. Eligible Lead-Time Delivery Events
-- 10. Unknown Lead-Time Delivery Events
-- 11. Weighted Lead Days
-- 12. Weighted Average Lead Time
--
-- =========================================================

WITH supplier_base AS (

    SELECT

        supplier_id,

        COUNT(DISTINCT sku_id)
            AS distinct_skus,

        COUNT(*)
            AS sku_warehouse_records,

        -- Total recorded delivery events
        SUM(supplier_deliveries_count)
            AS total_delivery_events,

        -- Deliveries with known OTD outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_events,

        -- Number of on-time deliveries
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_events,

        -- Number of deliveries with unknown OTD
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_otd_events,

        -- Deliveries with known observed lead time
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_time_events,

        -- Deliveries with unknown observed lead time
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_lead_time_events,

        -- Weighted observed lead days
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN
                    replenishment_lead_time_days
                    * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

    GROUP BY supplier_id

),

supplier_kpis AS (

    SELECT

        supplier_id,

        distinct_skus,

        sku_warehouse_records,

        total_delivery_events,

        eligible_otd_events,

        on_time_events,

        -- Late deliveries:
        -- Eligible deliveries minus on-time deliveries
        eligible_otd_events - on_time_events
            AS late_delivery_events,

        unknown_otd_events,

        -- Supplier on-time delivery rate
        ROUND(
            on_time_events * 100.0 /
            NULLIF(eligible_otd_events, 0),
            2
        ) AS supplier_otd_pct,

        eligible_lead_time_events,

        unknown_lead_time_events,

        weighted_lead_days,

        -- Delivery-weighted lead time
        ROUND(
            weighted_lead_days * 1.0 /
            NULLIF(eligible_lead_time_events, 0),
            2
        ) AS avg_lead_time_days

    FROM supplier_base

)

SELECT

    supplier_id,

    distinct_skus,

    sku_warehouse_records,

    total_delivery_events,

    eligible_otd_events,

    on_time_events,

    late_delivery_events,

    unknown_otd_events,

    supplier_otd_pct,

    eligible_lead_time_events,

    unknown_lead_time_events,

    weighted_lead_days,

    avg_lead_time_days

FROM supplier_kpis

ORDER BY supplier_id;
-- =========================================================
-- SECTION 06.1: VERIFIED OCTOBER SUPPLIER KPI RESULTS
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
-- 12 Suppliers x 13 Columns
--
-- VALIDATION STATUS:
-- PASSED - Portfolio totals reconciled to Script 03.
--
-- =========================================================
-- A. PORTFOLIO DELIVERY RECONCILIATION
-- =========================================================
--
-- Total Suppliers                  : 12
-- Distinct SKUs Supported          : 120
-- SKU-Warehouse Records            : 360
--
-- Total Recorded Delivery Events   : 730
--
-- Eligible OTD Events              : 729
-- On-Time Delivery Events          : 646
-- Known Late Delivery Events       : 83
-- Unknown OTD Events               : 1
--
-- Delivery Reconciliation:
-- 646 + 83 + 1 = 730
--
-- Portfolio Supplier OTD:
-- 646 / 729 * 100
-- = 88.61%
--
-- Eligible Lead-Time Events        : 729
-- Unknown Lead-Time Events         : 1
-- Weighted Observed Lead Days      : 7920
--
-- Portfolio Weighted Lead Time:
-- 7920 / 729
-- = 10.86 days
--
-- Both portfolio KPIs match verified
-- October results from 03_business_kpis.sql.
--
-- =========================================================
-- B. VERIFIED INDIVIDUAL SUPPLIER RESULTS
-- =========================================================
--
-- Supplier   OTD %   Late Events   Avg Lead Days
--
-- SUP001     79.03       13           12.95
-- SUP002     92.54        5           11.90
-- SUP003     80.00       11            5.64
-- SUP004    100.00        0           13.86
-- SUP005     87.72        7           13.89
-- SUP006     82.61       12            6.55
-- SUP007     75.81       15           13.37
-- SUP008     96.97        2           12.97
-- SUP009     81.36       11           13.43
-- SUP010     96.36        2           10.45
-- SUP011    100.00        0           11.02
-- SUP012     92.19        5            4.75
--
-- All 12 suppliers support 10 distinct SKUs
-- represented by 30 SKU-warehouse records each.
--
-- =========================================================
-- C. SUPPLIER OTD CALCULATION
-- =========================================================
--
-- Supplier OTD (%) =
-- Known On-Time Deliveries
-- / Eligible Deliveries * 100
--
-- Example: SUP007
--
-- Total Delivery Events            : 63
-- Eligible OTD Events              : 62
-- Known On-Time Events             : 47
-- Known Late Events                : 15
-- Unknown OTD Events               : 1
--
-- Supplier OTD =
-- 47 / 62 * 100
-- = 75.81%
--
-- IMPORTANT:
-- Unknown OTD events are excluded from the
-- denominator and reported separately.
--
-- =========================================================
-- D. WEIGHTED LEAD-TIME CALCULATION
-- =========================================================
--
-- Average Observed Lead Time =
-- SUM(Observed Lead Days * Delivery Count)
-- / SUM(Eligible Lead-Time Delivery Count)
--
-- Example: SUP012
--
-- Weighted Lead Days               : 304
-- Eligible Lead-Time Events        : 64
--
-- Average Lead Time =
-- 304 / 64
-- = 4.75 days
--
-- IMPORTANT:
-- A simple average of SKU-row lead times is
-- not equivalent to a delivery-weighted average.
--
-- =========================================================
-- E. MISSING-OBSERVATION HANDLING
-- =========================================================
--
-- SUP007:
-- 1 delivery has unknown OTD outcome.
-- Total deliveries = 63.
-- Eligible OTD deliveries = 62.
--
-- SUP009:
-- 1 delivery has unknown observed lead time.
-- Total deliveries = 59.
-- Eligible lead-time deliveries = 58.
--
-- These are different missing-observation
-- cases and affect different KPI denominators.
--
-- Unknown values must not be converted
-- to zero, on-time or late without evidence.
--
-- =========================================================
-- F. INITIAL SUPPLIER FINDINGS
-- =========================================================
--
-- LOWEST OCTOBER OTD:
-- SUP007 = 75.81%
--
-- SUP007 also has the highest late-delivery
-- event count at 15.
--
-- Contribution to Portfolio Late Deliveries:
-- 15 / 83 * 100
-- = 18.07%
--
-- HIGHEST OBSERVED OTD:
-- SUP004 = 100.00%, with 58 eligible deliveries.
-- SUP011 = 100.00%, with 55 eligible deliveries.
--
-- LONGEST WEIGHTED LEAD TIME:
-- SUP005 = 13.89 days.
--
-- SHORTEST WEIGHTED LEAD TIME:
-- SUP012 = 4.75 days.
--
-- =========================================================
-- G. SPEED VERSUS RELIABILITY
-- =========================================================
--
-- SUP003:
-- OTD = 80.00%
-- Average Lead Time = 5.64 days
--
-- SUP004:
-- OTD = 100.00%
-- Average Lead Time = 13.86 days
--
-- INTERPRETATION:
-- Delivery speed and on-time delivery
-- reliability measure different properties.
--
-- A longer lead time does not automatically
-- indicate poor delivery reliability.
--
-- =========================================================
-- H. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- INITIAL RELIABILITY INVESTIGATION:
-- SUP007
--
-- Evidence:
-- Lowest observed October OTD.
-- Highest known late-delivery count.
-- One unknown OTD event.
--
-- LEAD-TIME INVESTIGATION:
-- SUP005
--
-- Evidence:
-- Longest observed weighted lead time.
--
-- REFERENCE SUPPLIERS FOR COMPARISON:
-- SUP004 and SUP011
--
-- Evidence:
-- 100% observed October OTD.
--
-- NOTE:
-- These are investigation priorities.
-- They are not confirmed root causes of stockouts.
--
-- =========================================================
-- I. LIMITATIONS
-- =========================================================
--
-- 1. Data represents a synthetic scenario.
--
-- 2. October results alone do not establish
--    sustained supplier underperformance.
--
-- 3. OTD percentages must be interpreted
--    alongside eligible delivery counts.
--
-- 4. Lead time and reliability are distinct KPIs.
--
-- 5. Missing delivery observations reduce
--    the eligible population for relevant KPIs.
--
-- 6. Supplier-linked inventory shortages do
--    not independently prove supplier causation.
--
-- 7. Individual delivery timestamps and
--    contractual service targets are not
--    validated by this aggregate scorecard.
--
-- =========================================================
-- J. NEXT ANALYSIS
-- =========================================================
--
-- SECTION 06.2:
-- Supplier Reliability Rankings & Contribution
--
-- OBJECTIVES:
-- - Rank supplier OTD performance.
-- - Rank known late-delivery volumes.
-- - Rank weighted observed lead times.
-- - Calculate supplier contribution to
--   portfolio late-delivery events.
-- - Preserve ranking ties.
-- - Consider delivery volumes and unknowns.
--
-- SECTION 06.1 VALIDATION STATUS:
-- PASSED
-- =========================================================
-- =========================================================
-- SECTION 06.2: SUPPLIER RELIABILITY RANKINGS
--            & LATE-DELIVERY CONTRIBUTION
-- =========================================================
--
-- BUSINESS QUESTION:
-- Which suppliers contribute most to late
-- deliveries, and how do their reliability
-- and lead-time metrics compare?
--
-- REPORTING MONTH:
-- October 2026
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- EXPECTED OUTPUT:
-- 12 supplier rows
--
-- ANALYTICAL METHOD:
-- 1. Aggregate supplier delivery events.
-- 2. Calculate full-precision supplier KPIs.
-- 3. Calculate portfolio delivery totals.
-- 4. Calculate supplier contribution shares.
-- 5. Rank suppliers with DENSE_RANK().
-- 6. Round only in the final SELECT.
--
-- IMPORTANT:
-- Unknown OTD outcomes remain excluded from
-- the eligible OTD population.
--
-- Rankings are independent dimensions.
-- No arbitrary composite risk score is used.
-- =========================================================

WITH supplier_base AS (

    SELECT

        supplier_id,

        -- Total recorded deliveries
        SUM(supplier_deliveries_count)
            AS total_delivery_events,

        -- Deliveries with known OTD outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_events,

        -- Known on-time deliveries
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_events,

        -- Deliveries with unknown OTD outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_otd_events,

        -- Eligible lead-time delivery events
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_time_events,

        -- Weighted observed lead days
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN
                    replenishment_lead_time_days
                    * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

    GROUP BY supplier_id

),

supplier_kpis AS (

    SELECT

        supplier_id,

        total_delivery_events,

        eligible_otd_events,

        on_time_events,

        unknown_otd_events,

        eligible_lead_time_events,

        -- Known late delivery count
        eligible_otd_events - on_time_events
            AS late_delivery_events,

        -- Full-precision supplier OTD rate
        on_time_events * 100.0 /
        NULLIF(eligible_otd_events, 0)
            AS otd_rate_pct,

        -- Full-precision late-delivery rate
        (eligible_otd_events - on_time_events)
            * 100.0 /
        NULLIF(eligible_otd_events, 0)
            AS late_rate_pct,

        -- Full-precision weighted average lead time
        weighted_lead_days * 1.0 /
        NULLIF(eligible_lead_time_events, 0)
            AS avg_lead_time_days

    FROM supplier_base

),

supplier_rankings AS (

    SELECT

        supplier_kpis.*,

        -- Portfolio eligible OTD events
        SUM(eligible_otd_events) OVER ()
            AS portfolio_eligible_otd_events,

        -- Portfolio known late delivery events
        SUM(late_delivery_events) OVER ()
            AS portfolio_late_events,

        -- Lowest OTD gets Rank 1
        DENSE_RANK() OVER (
            ORDER BY otd_rate_pct ASC
        ) AS otd_risk_rank,

        -- Most late events gets Rank 1
        DENSE_RANK() OVER (
            ORDER BY late_delivery_events DESC
        ) AS late_volume_rank,

        -- Longest lead time gets Rank 1
        DENSE_RANK() OVER (
            ORDER BY avg_lead_time_days DESC
        ) AS lead_time_rank

    FROM supplier_kpis

)

SELECT

    supplier_id,

    -- Delivery volume
    eligible_otd_events,

    -- Known late events
    late_delivery_events,

    -- Unknown OTD events
    unknown_otd_events,

    -- Supplier reliability
    ROUND(
        otd_rate_pct,
        2
    ) AS supplier_otd_pct,

    -- Supplier late-delivery rate
    ROUND(
        late_rate_pct,
        2
    ) AS late_delivery_rate_pct,

    -- Supplier share of eligible delivery events
    ROUND(
        eligible_otd_events * 100.0 /
        NULLIF(portfolio_eligible_otd_events, 0),
        2
    ) AS eligible_delivery_share_pct,

    -- Supplier share of portfolio late events
    ROUND(
        late_delivery_events * 100.0 /
        NULLIF(portfolio_late_events, 0),
        2
    ) AS late_delivery_share_pct,

    -- Disproportionate late-delivery contribution
    ROUND(
        (
            late_delivery_events * 100.0 /
            NULLIF(portfolio_late_events, 0)
        )
        -
        (
            eligible_otd_events * 100.0 /
            NULLIF(portfolio_eligible_otd_events, 0)
        ),
        2
    ) AS excess_late_share_pp,

    -- Lead-time eligibility denominator
    eligible_lead_time_events,

    -- Weighted observed lead time
    ROUND(
        avg_lead_time_days,
        2
    ) AS avg_lead_time_days,

    -- Three independent supplier rankings
    otd_risk_rank,

    late_volume_rank,

    lead_time_rank

FROM supplier_rankings

ORDER BY supplier_id;
-- =========================================================
-- SECTION 06.2: VERIFIED SUPPLIER RELIABILITY RANKINGS
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
-- OUTPUT:
-- 12 Suppliers x 14 Columns
--
-- VALIDATION STATUS:
-- PASSED
--
-- =========================================================
-- A. PORTFOLIO RECONCILIATION
-- =========================================================
--
-- Suppliers Analyzed             : 12
-- Eligible OTD Deliveries        : 729
-- Known Late Deliveries          : 83
-- Unknown OTD Deliveries         : 1
-- Eligible Lead-Time Deliveries  : 729
--
-- Total Recorded Deliveries:
-- 729 + 1 = 730
--
-- Portfolio Late-Delivery Rate:
-- 83 / 729 * 100
-- = 11.39%
--
-- Portfolio On-Time Delivery Rate:
-- 646 / 729 * 100
-- = 88.61%
--
-- =========================================================
-- B. VERIFIED SUPPLIER PERFORMANCE
-- =========================================================
--
-- Supplier   OTD %    Late   Late Share   Excess Share
--
-- SUP001     79.03     13      15.66%       +7.16 pp
-- SUP002     92.54      5       6.02%       -3.17 pp
-- SUP003     80.00     11      13.25%       +5.71 pp
-- SUP004    100.00      0       0.00%       -7.96 pp
-- SUP005     87.72      7       8.43%       +0.61 pp
-- SUP006     82.61     12      14.46%       +4.99 pp
-- SUP007     75.81     15      18.07%       +9.57 pp
-- SUP008     96.97      2       2.41%       -6.64 pp
-- SUP009     81.36     11      13.25%       +5.16 pp
-- SUP010     96.36      2       2.41%       -5.13 pp
-- SUP011    100.00      0       0.00%       -7.54 pp
-- SUP012     92.19      5       6.02%       -2.76 pp
--
-- =========================================================
-- C. VERIFIED RISK RANKINGS
-- =========================================================
--
-- Supplier   OTD Rank   Late Rank   Lead-Time Rank
--
-- SUP001        2           2              6
-- SUP002        8           6              7
-- SUP003        3           4             11
-- SUP004       11           8              2
-- SUP005        6           5              1
-- SUP006        5           3             10
-- SUP007        1           1              4
-- SUP008       10           7              5
-- SUP009        4           4              3
-- SUP010        9           7              9
-- SUP011       11           8              8
-- SUP012        7           6             12
--
-- RANKING DEFINITIONS:
--
-- OTD Risk Rank:
-- Lowest eligible OTD percentage = Rank 1
--
-- Late-Volume Rank:
-- Most known late deliveries = Rank 1
--
-- Lead-Time Rank:
-- Longest weighted observed lead time = Rank 1
--
-- DENSE_RANK() preserves tied rankings.
--
-- Example:
-- SUP004 and SUP011 both have 100% OTD
-- and therefore share OTD Risk Rank 11.
--
-- =========================================================
-- D. CONTRIBUTION VALIDATION
-- =========================================================
--
-- Displayed Eligible Delivery Shares:
-- 99.98%
--
-- Displayed Late-Delivery Shares:
-- 99.98%
--
-- Displayed Excess Shares:
-- 0.00 percentage points
--
-- IMPORTANT:
-- Individual supplier percentages are rounded
-- to two decimal places for display.
--
-- Unrounded contribution shares total 100%.
-- The displayed 0.02 percentage-point difference
-- is due to rounding.
--
-- =========================================================
-- E. SUP007 MATHEMATICAL VERIFICATION
-- =========================================================
--
-- Eligible OTD Events       : 62
-- Known On-Time Events      : 47
-- Known Late Events         : 15
-- Unknown OTD Events        : 1
--
-- SUP007 OTD:
-- 47 / 62 * 100
-- = 75.81%
--
-- SUP007 Late-Delivery Rate:
-- 15 / 62 * 100
-- = 24.19%
--
-- Eligible Delivery Share:
-- 62 / 729 * 100
-- = 8.50%
--
-- Portfolio Late-Delivery Share:
-- 15 / 83 * 100
-- = 18.07%
--
-- Excess Late-Delivery Share:
-- (15 / 83 * 100) - (62 / 729 * 100)
-- = +9.57 percentage points
--
-- INTERPRETATION:
-- SUP007 contributes disproportionately
-- to known late-delivery events.
--
-- It has the lowest observed OTD percentage
-- and the highest known late-delivery count.
--
-- =========================================================
-- F. LATE-DELIVERY CONCENTRATION
-- =========================================================
--
-- TOP THREE BY KNOWN LATE DELIVERIES:
--
-- SUP007 : 15
-- SUP001 : 13
-- SUP006 : 12
--
-- Combined Late Deliveries:
-- 15 + 13 + 12 = 40
--
-- Portfolio Late Share:
-- 40 / 83 * 100 = 48.19%
--
-- Combined Eligible OTD Deliveries:
-- 62 + 62 + 69 = 193
--
-- Eligible Delivery Share:
-- 193 / 729 * 100 = 26.47%
--
-- INTERPRETATION:
-- These three suppliers represent about
-- 26.47% of eligible delivery volume,
-- but 48.19% of known late deliveries.
--
-- TOP FIVE BY KNOWN LATE DELIVERIES:
--
-- SUP007 : 15
-- SUP001 : 13
-- SUP006 : 12
-- SUP003 : 11
-- SUP009 : 11
--
-- Combined Late Deliveries:
-- 62
--
-- Portfolio Late Share:
-- 62 / 83 * 100 = 74.70%
--
-- INTERPRETATION:
-- These five suppliers account for nearly
-- three-quarters of known late deliveries.
--
-- =========================================================
-- G. LEAD-TIME INVESTIGATION
-- =========================================================
--
-- Longest Weighted Observed Lead Time:
-- SUP005 = 13.89 days
--
-- Shortest Weighted Observed Lead Time:
-- SUP012 = 4.75 days
--
-- SUP004:
-- Average Lead Time = 13.86 days
-- OTD Rate          = 100.00%
--
-- SUP007:
-- Average Lead Time = 13.37 days
-- OTD Rate          = 75.81%
--
-- IMPORTANT:
-- Longer lead time does not automatically
-- mean poor on-time delivery reliability.
--
-- Contractual lead-time expectations must
-- be considered before judging delays.
--
-- =========================================================
-- H. DATA COMPLETENESS
-- =========================================================
--
-- SUP007:
-- Unknown OTD Events = 1
--
-- SUP009:
-- OTD-Eligible Deliveries       = 59
-- Lead-Time-Eligible Deliveries = 58
--
-- Eligibility populations differ.
--
-- Unknown observations remain excluded
-- from their respective KPI denominators.
--
-- =========================================================
-- I. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- PRIORITY 1: DELIVERY RELIABILITY
--
-- Supplier: SUP007
--
-- Evidence:
-- Lowest October OTD = 75.81%
-- Highest known late deliveries = 15
-- Largest excess late share = +9.57 pp
--
-- PRIORITY 2: LATE-DELIVERY CONCENTRATION
--
-- Suppliers:
-- SUP007, SUP001, SUP006, SUP003, SUP009
--
-- Evidence:
-- 62 of 83 known late deliveries.
-- Combined contribution = 74.70%
--
-- PRIORITY 3: LONG LEAD TIME
--
-- Supplier: SUP005
--
-- Evidence:
-- Longest weighted observed lead time
-- of 13.89 days.
--
-- These priorities require additional investigation
-- before supplier-related corrective actions.
--
-- =========================================================
-- J. SQL METHODS
-- =========================================================
--
-- SUM(metric) OVER():
-- Calculates portfolio totals without removing
-- individual supplier rows.
--
-- DENSE_RANK():
-- Assigns independent rankings and retains ties.
--
-- NULLIF():
-- Prevents division by zero.
--
-- ROUND():
-- Used only in final presentation calculations.
--
-- =========================================================
-- K. ANALYTICAL LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business data.
--
-- 2. Only October 2026 is examined here.
--
-- 3. Historical evidence is needed before
--    claiming persistent poor reliability.
--
-- 4. Observed lead time and OTD describe
--    different supplier characteristics.
--
-- 5. Supplier delivery event counts are
--    aggregated observations, not individual
--    timestamped shipment records.
--
-- 6. Missing observations reduce eligible
--    KPI populations.
--
-- 7. Supplier-linked stockouts cannot be
--    attributed causally without further evidence.
--
-- =========================================================
-- NEXT:
-- SECTION 06.3: HISTORICAL SUPPLIER PERFORMANCE
-- =========================================================
--
-- Investigate:
-- - Twelve-month OTD trends
-- - Weighted historical lead times
-- - Persistent late-delivery contributors
-- - Supplier performance volatility
-- - Recurrent versus recent reliability issues
--
-- SECTION 06.2 VALIDATION STATUS:
-- PASSED
-- =========================================================
-- =========================================================
-- SECTION 06.3A: HISTORICAL SUPPLIER PERFORMANCE
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
-- 1. Which suppliers are historically unreliable?
-- 2. Which suppliers contribute most late deliveries?
-- 3. Which suppliers have longer observed lead times?
-- 4. Which suppliers underperform repeatedly?
-- 5. Did October performance improve or deteriorate?
--
-- SOURCE:
-- supply_chain_ai_db.inventory
--
-- OUTPUT:
-- One row per supplier (12 expected)
--
-- IMPORTANT:
-- Historical OTD and average lead time are
-- calculated using delivery-weighted totals.
--
-- Unknown outcomes remain excluded from
-- their respective eligible denominators.
--
-- No arbitrary supplier risk score is used.
-- =========================================================


WITH supplier_monthly_base AS (

    SELECT

        reporting_month,

        supplier_id,

        -- Recorded delivery events
        SUM(supplier_deliveries_count)
            AS total_delivery_events,

        -- Deliveries with known OTD outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_events,

        -- Known on-time delivery events
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_events,

        -- Unknown on-time outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_otd_events,

        -- Deliveries with known observed lead times
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_events,

        -- Deliveries with unknown lead times
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_lead_events,

        -- Delivery-weighted lead days
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN
                    replenishment_lead_time_days
                    * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month BETWEEN
          '2025-11-01' AND '2026-10-01'

    GROUP BY reporting_month, supplier_id

),

-- =========================================================
-- STEP 2: CALCULATE SUPPLIER-MONTH KPIs
-- =========================================================

supplier_monthly_kpis AS (

    SELECT

        supplier_monthly_base.*,

        -- Known late delivery events
        eligible_otd_events - on_time_events
            AS late_delivery_events,

        -- Full-precision monthly OTD
        on_time_events * 100.0 /
        NULLIF(eligible_otd_events, 0)
            AS otd_rate_pct,

        -- Full-precision weighted lead time
        weighted_lead_days * 1.0 /
        NULLIF(eligible_lead_events, 0)
            AS avg_lead_days

    FROM supplier_monthly_base

),

-- =========================================================
-- STEP 3: MONTHLY COMPARISONS AND RANKINGS
-- =========================================================

supplier_monthly_comparison AS (

    SELECT

        supplier_monthly_kpis.*,

        -- Total eligible deliveries across all suppliers
        -- within the same reporting month
        SUM(eligible_otd_events) OVER (
            PARTITION BY reporting_month
        ) AS portfolio_monthly_eligible,

        -- Total on-time deliveries across all suppliers
        -- within the same reporting month
        SUM(on_time_events) OVER (
            PARTITION BY reporting_month
        ) AS portfolio_monthly_on_time,

        -- Monthly OTD risk rank:
        -- Lowest OTD = Rank 1.
        --
        -- Suppliers without eligible OTD events
        -- sort after suppliers with known outcomes.
        DENSE_RANK() OVER (

            PARTITION BY reporting_month

            ORDER BY

                CASE
                    WHEN eligible_otd_events = 0
                    THEN 1 ELSE 0
                END ASC,

                otd_rate_pct ASC

        ) AS monthly_otd_risk_rank,

        -- Prior monthly OTD for the same supplier
        LAG(otd_rate_pct) OVER (

            PARTITION BY supplier_id

            ORDER BY reporting_month

        ) AS previous_otd_pct,

        -- Prior reporting month for continuity check
        LAG(reporting_month) OVER (

            PARTITION BY supplier_id

            ORDER BY reporting_month

        ) AS previous_reporting_month

    FROM supplier_monthly_kpis

),

-- =========================================================
-- STEP 4: HISTORICAL SUPPLIER TOTALS
-- =========================================================

supplier_historical AS (

    SELECT

        supplier_id,

        COUNT(*) AS reporting_months,

        SUM(total_delivery_events)
            AS total_delivery_events,

        SUM(eligible_otd_events)
            AS total_eligible_otd_events,

        SUM(on_time_events)
            AS total_on_time_events,

        SUM(late_delivery_events)
            AS total_late_events,

        SUM(unknown_otd_events)
            AS total_unknown_otd_events,

        SUM(eligible_lead_events)
            AS total_eligible_lead_events,

        SUM(unknown_lead_events)
            AS total_unknown_lead_events,

        SUM(weighted_lead_days)
            AS total_weighted_lead_days,

        -- Months when supplier OTD was lower
        -- than the actual portfolio OTD that month.
        SUM(
            CASE
                WHEN eligible_otd_events > 0
                 AND otd_rate_pct < (
                     portfolio_monthly_on_time * 100.0
                     / NULLIF(
                         portfolio_monthly_eligible,
                         0
                     )
                 )
                THEN 1 ELSE 0
            END
        ) AS months_below_portfolio_otd,

        -- Number of months supplier had the lowest
        -- eligible OTD rate among all suppliers.
        SUM(
            CASE
                WHEN eligible_otd_events > 0
                 AND monthly_otd_risk_rank = 1
                THEN 1 ELSE 0
            END
        ) AS months_lowest_otd,

        -- October OTD (for Section 06.1 reconciliation)
        MAX(
            CASE
                WHEN reporting_month = '2026-10-01'
                THEN otd_rate_pct
                ELSE NULL
            END
        ) AS october_otd_pct,

        -- October versus September OTD change.
        -- Only compare consecutive months.
        MAX(
            CASE
                WHEN reporting_month = '2026-10-01'
                 AND TIMESTAMPDIFF(
                     MONTH,
                     previous_reporting_month,
                     reporting_month
                 ) = 1
                THEN otd_rate_pct - previous_otd_pct
                ELSE NULL
            END
        ) AS october_otd_mom_pp

    FROM supplier_monthly_comparison

    GROUP BY supplier_id

),

-- =========================================================
-- STEP 5: CALCULATE WEIGHTED HISTORICAL KPIs
-- =========================================================

historical_kpis AS (

    SELECT

        supplier_historical.*,

        -- Weighted historical OTD
        total_on_time_events * 100.0 /
        NULLIF(total_eligible_otd_events, 0)
            AS historical_otd_pct,

        -- Weighted historical lead time
        total_weighted_lead_days * 1.0 /
        NULLIF(total_eligible_lead_events, 0)
            AS historical_avg_lead_days

    FROM supplier_historical

)

-- =========================================================
-- FINAL: TWELVE-SUPPLIER HISTORICAL COMPARISON
-- =========================================================

SELECT

    supplier_id,

    reporting_months,

    total_delivery_events,

    total_eligible_otd_events,

    total_late_events,

    total_unknown_otd_events,

    -- Weighted historical OTD
    ROUND(
        historical_otd_pct,
        2
    ) AS historical_otd_pct,

    -- Weighted historical lead time
    ROUND(
        historical_avg_lead_days,
        2
    ) AS historical_avg_lead_days,

    total_unknown_lead_events,

    -- Repeated monthly underperformance
    months_below_portfolio_otd,

    months_lowest_otd,

    -- Share of all known late deliveries
    ROUND(
        total_late_events * 100.0 /
        NULLIF(
            SUM(total_late_events) OVER (),
            0
        ),
        2
    ) AS historical_late_share_pct,

    -- Verified October performance
    ROUND(
        october_otd_pct,
        2
    ) AS october_otd_pct,

    -- October versus September
    ROUND(
        october_otd_mom_pp,
        2
    ) AS october_otd_mom_pp,

    -- Lowest historical OTD = Rank 1
    DENSE_RANK() OVER (

        ORDER BY
            CASE
                WHEN total_eligible_otd_events = 0
                THEN 1 ELSE 0
            END ASC,
            historical_otd_pct ASC

    ) AS historical_otd_risk_rank,

    -- Highest total late events = Rank 1
    DENSE_RANK() OVER (

        ORDER BY total_late_events DESC

    ) AS historical_late_volume_rank,

    -- Longest historical lead time = Rank 1
    DENSE_RANK() OVER (

        ORDER BY
            CASE
                WHEN total_eligible_lead_events = 0
                THEN 1 ELSE 0
            END ASC,
            historical_avg_lead_days DESC

    ) AS historical_lead_time_rank

FROM historical_kpis

ORDER BY supplier_id;
-- =========================================================
-- SECTION 06.3A: VERIFIED HISTORICAL SUPPLIER RESULTS
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
-- VALIDATION STATUS:
-- PASSED - Internal delivery counts and October
-- benchmark values reconciled.
--
-- =========================================================
-- A. HISTORICAL DELIVERY RECONCILIATION
-- =========================================================
--
-- Suppliers                     : 12
-- Reporting Months per Supplier : 12
-- Expected Supplier-Month Groups: 144
--
-- Recorded Delivery Events      : 8854
-- Eligible OTD Events           : 8837
-- Known On-Time Events          : 7828
-- Known Late Events             : 1009
-- Unknown OTD Events            : 17
-- Unknown Lead-Time Events      : 31
--
-- Delivery Reconciliation:
-- 7828 + 1009 + 17 = 8854
--
-- Historical Portfolio OTD:
-- 7828 / 8837 * 100
-- = 88.58%
--
-- IMPORTANT:
-- OTD and lead-time observations use separate
-- eligibility conditions.
--
-- The independent source-level audit remains
-- pending in Script 09.
--
-- =========================================================
-- B. VERIFIED HISTORICAL SUPPLIER PERFORMANCE
-- =========================================================
--
-- Supplier   OTD %   Late   Avg Lead Days   OTD Rank
--
-- SUP001     82.37    128       12.86          3
-- SUP002     92.77     58       12.29          7
-- SUP003     75.11    170        6.11          1
-- SUP004     97.30     21       13.20         12
-- SUP005     84.80    116       13.55          4
-- SUP006     84.88    114        6.54          5
-- SUP007     78.82    161       13.00          2
-- SUP008     96.67     24       12.98         11
-- SUP009     85.01    113       13.77          6
-- SUP010     96.20     26       10.24         10
-- SUP011     95.43     34       11.41          9
-- SUP012     93.41     44        5.42          8
--
-- All twelve October OTD values matched
-- the verified Section 06.1 results.
--
-- =========================================================
-- C. PERSISTENT RELIABILITY CONCERNS
-- =========================================================
--
-- SUP003:
-- Historical OTD                : 75.11%
-- Known Late Deliveries         : 170
-- Months Below Portfolio OTD    : 12 / 12
-- Months With Lowest OTD        : 6 / 12
-- Historical OTD Risk Rank      : 1
--
-- Historical Late Contribution:
-- 170 / 1009 * 100 = 16.85%
--
-- October OTD                   : 80.00%
-- October OTD MoM Change        : +6.92 pp
--
-- INTERPRETATION:
-- SUP003 is the strongest full-period
-- supplier reliability investigation priority.
--
-- October improvement does not eliminate
-- its repeated historical underperformance.
--
-- SUP007:
-- Historical OTD                : 78.82%
-- Known Late Deliveries         : 161
-- Months Below Portfolio OTD    : 12 / 12
-- Months With Lowest OTD        : 3 / 12
-- Historical OTD Risk Rank      : 2
--
-- Historical Late Contribution:
-- 161 / 1009 * 100 = 15.96%
--
-- October OTD                   : 75.81%
-- October OTD MoM Change        : +1.26 pp
--
-- INTERPRETATION:
-- SUP007 remains a persistent reliability
-- investigation priority and was October's
-- weakest supplier for observed OTD.
--
-- =========================================================
-- D. HISTORICAL LATE-DELIVERY CONCENTRATION
-- =========================================================
--
-- TOP THREE:
--
-- SUP003 : 170
-- SUP007 : 161
-- SUP001 : 128
--
-- Total:
-- 459
--
-- Portfolio Late Contribution:
-- 459 / 1009 * 100 = 45.49%
--
-- TOP FIVE:
--
-- SUP003 : 170
-- SUP007 : 161
-- SUP001 : 128
-- SUP005 : 116
-- SUP006 : 114
--
-- Total:
-- 689
--
-- Portfolio Late Contribution:
-- 689 / 1009 * 100 = 68.29%
--
-- INTERPRETATION:
-- A relatively small group contributes
-- most known historical late deliveries.
--
-- This concentration supports targeted
-- supplier investigation.
--
-- =========================================================
-- E. RECURRING RELATIVE UNDERPERFORMANCE
-- =========================================================
--
-- Supplier   Months Below Portfolio OTD
--
-- SUP001              11
-- SUP002               1
-- SUP003              12
-- SUP004               0
-- SUP005              11
-- SUP006              12
-- SUP007              12
-- SUP008               1
-- SUP009              10
-- SUP010               0
-- SUP011               0
-- SUP012               1
--
-- Monthly OTD Rank 1 Frequency:
--
-- SUP001 : 2 months
-- SUP003 : 6 months
-- SUP006 : 1 month
-- SUP007 : 3 months
--
-- All other suppliers: 0 months.
--
-- The twelve lowest-month rankings
-- account for all twelve reporting months.
--
-- =========================================================
-- F. HISTORICAL OBSERVED LEAD TIMES
-- =========================================================
--
-- Longest Historical Weighted Lead Time:
-- SUP009 = 13.77 days
--
-- Second Longest:
-- SUP005 = 13.55 days
--
-- Shortest Historical Weighted Lead Time:
-- SUP012 = 5.42 days
--
-- Highest October Weighted Lead Time:
-- SUP005 = 13.89 days
--
-- IMPORTANT:
-- Longer observed lead time does not by
-- itself establish unreliable delivery.
--
-- =========================================================
-- G. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- HISTORICAL DELIVERY RELIABILITY:
-- SUP003 and SUP007
--
-- Evidence:
-- Lowest historical OTD percentages.
-- Highest cumulative known late counts.
-- Below monthly portfolio OTD in all
-- twelve reporting months.
--
-- LATE-DELIVERY CONCENTRATION:
-- SUP003, SUP007, SUP001, SUP005, SUP006
--
-- Evidence:
-- 689 of 1009 known late events.
-- Combined late-delivery contribution: 68.29%.
--
-- HISTORICAL REPLENISHMENT DURATION:
-- SUP009 and SUP005
--
-- Evidence:
-- Longest weighted observed lead times.
--
-- =========================================================
-- H. ANALYTICAL METHOD
-- =========================================================
--
-- Historical OTD:
-- SUM(Known On-Time Deliveries)
-- / SUM(Eligible OTD Deliveries) * 100
--
-- Historical Weighted Lead Time:
-- SUM(Observed Lead Time * Delivery Count)
-- / SUM(Eligible Lead-Time Delivery Count)
--
-- Monthly Underperformance:
-- Supplier OTD < Same-Month Portfolio OTD
--
-- Window Functions:
-- LAG(), DENSE_RANK(), SUM() OVER()
--
-- Full precision retained before rounding.
--
-- =========================================================
-- I. LIMITATIONS
-- =========================================================
--
-- 1. Data represents a synthetic scenario.
--
-- 2. Observations are aggregated delivery counts.
--
-- 3. Missing OTD and lead-time observations
--    reduce eligible KPI populations.
--
-- 4. Historical OTD must be delivery-weighted.
--
-- 5. Monthly relative performance does not
--    establish contractual SLA violations.
--
-- 6. Supplier underperformance does not
--    establish causation of warehouse stockouts.
--
-- 7. Monthly trend investigation remains pending.
--
-- 8. Independent SQL-Python reconciliation
--    is not yet complete.
--
-- =========================================================
-- NEXT:
-- SECTION 06.3B - MONTHLY SUPPLIER TRENDS
-- =========================================================
--
-- Investigate:
-- - Monthly OTD movements
-- - Weighted lead-time movements
-- - Repeated late-delivery volumes
-- - Persistent versus recent changes
-- - Supplier comparisons across 12 months
--
-- SECTION 06.3A STATUS: VERIFIED
-- =========================================================
-- =========================================================
-- SECTION 06.3B: MONTHLY SUPPLIER RELIABILITY
--               & LEAD-TIME TRENDS
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
-- 1. How did monthly supplier reliability change?
-- 2. Which suppliers repeatedly performed poorly?
-- 3. Did observed supplier lead times change?
-- 4. How does each supplier compare with the
--    company-wide OTD rate in the same month?
-- 5. Are recent trends consistent with
--    historical performance?
--
-- ANALYSIS SCOPE:
-- All 12 suppliers and all 12 reporting months.
--
-- DISPLAY SCOPE:
-- SUP003, SUP005, SUP007, SUP009.
--
-- EXPECTED OUTPUT:
-- 4 Suppliers x 12 Months = 48 Rows
--
-- IMPORTANT:
-- All portfolio metrics and rankings are
-- calculated BEFORE filtering to four suppliers.
--
-- Weighted metrics use eligible delivery counts.
-- Missing observations are not treated as zero.
-- =========================================================


WITH supplier_monthly_base AS (

    SELECT

        reporting_month,

        supplier_id,

        -- Deliveries with known OTD outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_events,

        -- Known on-time delivery events
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_events,

        -- Unknown on-time outcomes
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_otd_events,

        -- Eligible observed lead-time events
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_events,

        -- Unknown lead-time events
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS unknown_lead_events,

        -- Weighted observed lead days
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN
                    replenishment_lead_time_days
                    * supplier_deliveries_count
                ELSE 0
            END
        ) AS weighted_lead_days

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month BETWEEN
          '2025-11-01' AND '2026-10-01'

    GROUP BY reporting_month, supplier_id

),

-- =========================================================
-- STEP 2: MONTHLY SUPPLIER KPIs
-- =========================================================

supplier_monthly_kpis AS (

    SELECT

        supplier_monthly_base.*,

        -- Known late delivery events
        eligible_otd_events - on_time_events
            AS late_delivery_events,

        -- Full-precision monthly OTD
        on_time_events * 100.0 /
        NULLIF(eligible_otd_events, 0)
            AS supplier_otd_pct,

        -- Full-precision weighted lead time
        weighted_lead_days * 1.0 /
        NULLIF(eligible_lead_events, 0)
            AS avg_lead_days

    FROM supplier_monthly_base

),

-- =========================================================
-- STEP 3: COMPANY BENCHMARKS AND MONTHLY RANKINGS
-- =========================================================

supplier_monthly_context AS (

    SELECT

        supplier_monthly_kpis.*,

        -- All-supplier on-time events for the month
        SUM(on_time_events) OVER (
            PARTITION BY reporting_month
        ) AS portfolio_on_time_events,

        -- All-supplier eligible OTD events
        SUM(eligible_otd_events) OVER (
            PARTITION BY reporting_month
        ) AS portfolio_eligible_events,

        -- All-supplier known late events
        SUM(late_delivery_events) OVER (
            PARTITION BY reporting_month
        ) AS portfolio_late_events,

        -- Lowest monthly OTD = Rank 1
        -- Suppliers without known OTD are last.
        DENSE_RANK() OVER (

            PARTITION BY reporting_month

            ORDER BY

                CASE
                    WHEN eligible_otd_events = 0
                    THEN 1 ELSE 0
                END ASC,

                supplier_otd_pct ASC

        ) AS monthly_otd_risk_rank,

        -- Longest monthly lead time = Rank 1
        DENSE_RANK() OVER (

            PARTITION BY reporting_month

            ORDER BY

                CASE
                    WHEN eligible_lead_events = 0
                    THEN 1 ELSE 0
                END ASC,

                avg_lead_days DESC

        ) AS monthly_lead_time_rank

    FROM supplier_monthly_kpis

),

-- =========================================================
-- STEP 4: PREVIOUS-MONTH AND ROLLING CALCULATIONS
-- =========================================================

supplier_trends AS (

    SELECT

        supplier_monthly_context.*,

        -- Previous reporting month for this supplier
        LAG(reporting_month) OVER (

            PARTITION BY supplier_id
            ORDER BY reporting_month

        ) AS previous_reporting_month,

        -- OTD from previous month
        LAG(supplier_otd_pct) OVER (

            PARTITION BY supplier_id
            ORDER BY reporting_month

        ) AS previous_otd_pct,

        -- Lead time from previous month
        LAG(avg_lead_days) OVER (

            PARTITION BY supplier_id
            ORDER BY reporting_month

        ) AS previous_lead_days,

        -- Month two observations earlier
        LAG(reporting_month, 2) OVER (

            PARTITION BY supplier_id
            ORDER BY reporting_month

        ) AS two_months_ago,

        -- Rolling 3-month on-time delivery events
        SUM(on_time_events) OVER (

            PARTITION BY supplier_id

            ORDER BY reporting_month

            ROWS BETWEEN
                2 PRECEDING AND CURRENT ROW

        ) AS rolling_3m_on_time,

        -- Rolling 3-month eligible delivery events
        SUM(eligible_otd_events) OVER (

            PARTITION BY supplier_id

            ORDER BY reporting_month

            ROWS BETWEEN
                2 PRECEDING AND CURRENT ROW

        ) AS rolling_3m_eligible

    FROM supplier_monthly_context

)

-- =========================================================
-- STEP 5: DISPLAY FOCUSED MONTHLY SUPPLIER TRENDS
-- =========================================================

SELECT

    DATE_FORMAT(
        reporting_month, '%Y-%m'
    ) AS reporting_month,

    supplier_id,

    eligible_otd_events,

    late_delivery_events,

    unknown_otd_events,

    -- Current supplier monthly OTD
    ROUND(
        supplier_otd_pct,
        2
    ) AS supplier_otd_pct,

    -- Current company-wide OTD benchmark
    ROUND(
        portfolio_on_time_events * 100.0 /
        NULLIF(portfolio_eligible_events, 0),
        2
    ) AS portfolio_otd_pct,

    -- Supplier minus portfolio OTD
    -- Negative means below company performance.
    ROUND(
        supplier_otd_pct
        -
        (
            portfolio_on_time_events * 100.0 /
            NULLIF(portfolio_eligible_events, 0)
        ),
        2
    ) AS otd_gap_pp,

    -- Supplier OTD change vs previous month
    ROUND(
        CASE
            WHEN TIMESTAMPDIFF(
                MONTH,
                previous_reporting_month,
                reporting_month
            ) = 1
            THEN supplier_otd_pct - previous_otd_pct
            ELSE NULL
        END,
        2
    ) AS otd_mom_change_pp,

    monthly_otd_risk_rank,

    eligible_lead_events,

    unknown_lead_events,

    -- Current weighted supplier lead time
    ROUND(
        avg_lead_days,
        2
    ) AS avg_lead_days,

    -- Lead-time change vs previous month
    ROUND(
        CASE
            WHEN TIMESTAMPDIFF(
                MONTH,
                previous_reporting_month,
                reporting_month
            ) = 1
            THEN avg_lead_days - previous_lead_days
            ELSE NULL
        END,
        2
    ) AS lead_time_mom_change_days,

    monthly_lead_time_rank,

    -- Share of portfolio's known late deliveries
    ROUND(
        late_delivery_events * 100.0 /
        NULLIF(portfolio_late_events, 0),
        2
    ) AS monthly_late_share_pct,

    -- Recent 3-month weighted OTD.
    -- Require three consecutive calendar months.
    ROUND(
        CASE
            WHEN TIMESTAMPDIFF(
                MONTH,
                two_months_ago,
                reporting_month
            ) = 2

            THEN rolling_3m_on_time * 100.0 /
                 NULLIF(rolling_3m_eligible, 0)

            ELSE NULL
        END,
        2
    ) AS rolling_3m_otd_pct

FROM supplier_trends

-- Filter AFTER calculating all-supplier
-- benchmarks, rankings and window metrics.
WHERE supplier_id IN (
    'SUP003',
    'SUP005',
    'SUP007',
    'SUP009'
)

ORDER BY reporting_month, supplier_id;
-- =========================================================
-- SECTION 06.3B: VERIFIED MONTHLY SUPPLIER TRENDS
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
-- ANALYSIS:
-- All 12 suppliers across 12 reporting months.
--
-- DISPLAY:
-- SUP003, SUP005, SUP007, SUP009
--
-- VERIFIED OUTPUT:
-- 48 supplier-month rows, 17 columns.
--
-- VALIDATION STATUS:
-- PASSED - Monthly and historical consistency.
--
-- =========================================================
-- A. DATA COMPLETENESS
-- =========================================================
--
-- Focus Suppliers                     : 4
-- Reporting Months per Focus Supplier : 12
-- Displayed Supplier-Month Records    : 48
--
-- Monthly Portfolio OTD:
-- Matched the twelve previously verified
-- monthly benchmark values from Script 04.
--
-- November 2025 MoM Comparisons:
-- NULL for all four suppliers.
--
-- November and December Rolling 3M OTD:
-- NULL because three months are not yet available.
--
-- October OTD Values:
-- Matched verified Section 06.1 results.
--
-- Monthly Lowest OTD Frequency:
-- Matched verified Section 06.3A results.
--
-- =========================================================
-- B. VERIFIED MONTHLY OTD PERCENTAGES
-- =========================================================
--
-- Month    Portfolio  SUP003  SUP005  SUP007  SUP009
--
-- 2025-11    88.83     73.91   83.61   72.73   85.14
-- 2025-12    89.24     77.97   84.62   78.69   88.57
-- 2026-01    89.42     76.27   88.33   80.00   78.85
-- 2026-02    87.16     74.24   78.38   82.35   87.50
-- 2026-03    87.76     78.46   89.86   83.64   86.15
-- 2026-04    88.05     75.93   84.00   78.26   82.81
-- 2026-05    90.03     76.60   86.96   84.93   78.69
-- 2026-06    87.11     65.08   83.33   78.13   91.30
-- 2026-07    87.66     69.35   78.46   76.67   85.45
-- 2026-08    90.40     81.82   88.06   79.03   85.90
-- 2026-09    88.64     73.08   84.85   74.55   86.27
-- 2026-10    88.61     80.00   87.72   75.81   81.36
--
-- =========================================================
-- C. SUP003: PERSISTENT RELIABILITY CONCERN
-- =========================================================
--
-- Historical Weighted OTD       : 75.11%
-- Months Below Portfolio OTD    : 12 / 12
-- Months With Lowest OTD        : 6 / 12
--
-- Worst Observed Month:
-- June 2026
--
-- June Eligible OTD Deliveries  : 63
-- June Late Deliveries          : 22
-- June Supplier OTD             : 65.08%
-- June Portfolio OTD            : 87.11%
-- June OTD Gap                  : -22.04 pp
--
-- Rolling 3M OTD:
-- July 2026                    : 69.77%
-- October 2026                 : 78.40%
--
-- Rolling Improvement:
-- +8.63 percentage points
--
-- October Monthly OTD:
-- 80.00%
--
-- October Monthly OTD MoM:
-- +6.92 percentage points
--
-- INTERPRETATION:
-- SUP003 has improved from its midyear
-- deterioration but remains below the
-- portfolio OTD benchmark.
--
-- =========================================================
-- D. SUP007: RECENT RELIABILITY DETERIORATION
-- =========================================================
--
-- Historical Weighted OTD       : 78.82%
-- Months Below Portfolio OTD    : 12 / 12
-- Months With Lowest OTD        : 3 / 12
--
-- Rolling 3M OTD:
--
-- May 2026       : 82.23%
-- June 2026      : 80.58%
-- July 2026      : 80.20%
-- August 2026    : 77.96%
-- September 2026 : 76.84%
-- October 2026   : 76.54%
--
-- Rolling Change May to October:
-- 76.54 - 82.23 = -5.69 pp
--
-- October Monthly OTD           : 75.81%
-- October Monthly OTD MoM       : +1.26 pp
-- October OTD Gap vs Portfolio  : -12.81 pp
--
-- INTERPRETATION:
-- A small one-month improvement does not
-- reverse the broader deterioration in
-- SUP007's rolling delivery reliability.
--
-- =========================================================
-- E. SUP005: LONG LEAD TIME, IMPROVING OTD
-- =========================================================
--
-- Historical Weighted OTD:
-- 84.80%
--
-- Historical Weighted Lead Time:
-- 13.55 days
--
-- October OTD:
-- 87.72%
--
-- October Weighted Lead Time:
-- 13.89 days
--
-- Months With Longest Lead-Time Rank:
-- 3
--
-- March, July and October 2026.
--
-- Rolling 3M OTD:
--
-- July 2026      : 82.99%
-- August 2026    : 83.33%
-- September 2026 : 83.84%
-- October 2026   : 86.84%
--
-- INTERPRETATION:
-- Recent OTD improvement is observed despite
-- persistently long replenishment durations.
--
-- Further investigation should compare
-- observed and expected supplier lead times.
--
-- =========================================================
-- F. SUP009: LONG HISTORICAL LEAD TIMES
-- =========================================================
--
-- Historical Weighted OTD:
-- 85.01%
--
-- Historical Weighted Lead Time:
-- 13.77 days
--
-- Months With Longest Lead-Time Rank:
-- 8 of 12
--
-- Monthly Observed Lead-Time Range:
-- 13.40 to 14.20 days
--
-- October OTD:
-- 81.36%
--
-- October OTD MoM:
-- -4.92 percentage points
--
-- October Observed Lead Time:
-- 13.43 days
--
-- October Lead-Time MoM:
-- -0.59 days
--
-- Rolling 3M OTD:
--
-- August 2026    : 87.62%
-- September 2026 : 85.87%
-- October 2026   : 84.57%
--
-- INTERPRETATION:
-- SUP009 consistently has among the
-- longest observed supplier lead times.
--
-- Recent OTD performance has weakened.
--
-- =========================================================
-- G. OCTOBER ROLLING 3M OTD RECONCILIATION
-- =========================================================
--
-- PERIOD:
-- August through October 2026.
--
-- SUP003:
-- On-Time Events      : 127
-- Eligible OTD Events : 162
-- Rolling OTD         : 78.40%
--
-- SUP005:
-- On-Time Events      : 165
-- Eligible OTD Events : 190
-- Rolling OTD         : 86.84%
--
-- SUP007:
-- On-Time Events      : 137
-- Eligible OTD Events : 179
-- Rolling OTD         : 76.54%
--
-- SUP009:
-- On-Time Events      : 159
-- Eligible OTD Events : 188
-- Rolling OTD         : 84.57%
--
-- All four October rolling calculations
-- were independently recalculated from
-- the displayed monthly delivery counts.
--
-- =========================================================
-- H. MISSING-OBSERVATION HANDLING
-- =========================================================
--
-- SUP003:
-- Unknown OTD Events       : 3
-- Unknown Lead-Time Events : 3
--
-- SUP005:
-- Unknown OTD Events       : 0
-- Unknown Lead-Time Events : 6
--
-- SUP007:
-- Unknown OTD Events       : 5
-- Unknown Lead-Time Events : 2
--
-- SUP009:
-- Unknown OTD Events       : 3
-- Unknown Lead-Time Events : 6
--
-- OTD and lead-time eligibility populations
-- remain separate.
--
-- Unknown values are not automatically
-- classified as late or assigned zero days.
--
-- =========================================================
-- I. SQL METHODS
-- =========================================================
--
-- GROUP BY reporting_month, supplier_id:
-- Creates supplier-month aggregates.
--
-- SUM(...) OVER (
--   PARTITION BY reporting_month
-- ):
-- Calculates monthly portfolio benchmarks.
--
-- DENSE_RANK() OVER (
--   PARTITION BY reporting_month
--   ORDER BY ...
-- ):
-- Ranks all suppliers within each month.
--
-- LAG() OVER (
--   PARTITION BY supplier_id
--   ORDER BY reporting_month
-- ):
-- Calculates supplier-specific MoM values.
--
-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW:
-- Defines the latest three monthly records.
--
-- Rolling OTD:
-- Rolling On-Time Events /
-- Rolling Eligible OTD Events * 100
--
-- Three consecutive months are required
-- before calculating rolling 3M OTD.
--
-- =========================================================
-- J. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- 1. SUP003:
-- Investigate persistent low OTD and
-- June 2026 performance deterioration.
--
-- 2. SUP007:
-- Investigate recent rolling OTD decline
-- and October late-delivery concentration.
--
-- 3. SUP009:
-- Investigate consistently long lead times
-- and recent OTD deterioration.
--
-- 4. SUP005:
-- Review replenishment planning assumptions
-- while acknowledging recent OTD improvement.
--
-- IMPORTANT:
-- These are investigation priorities,
-- not confirmed stockout root causes.
--
-- =========================================================
-- K. LIMITATIONS
-- =========================================================
--
-- 1. Synthetic business data.
--
-- 2. Results are aggregated supplier-month
--    observations, not individual shipment logs.
--
-- 3. Portfolio OTD is delivery-weighted.
--
-- 4. Rolling 3M OTD is delivery-weighted.
--
-- 5. Observed lead time does not necessarily
--    represent delay beyond agreed lead time.
--
-- 6. Relative OTD performance is not a
--    contractual SLA compliance assessment.
--
-- 7. Supplier performance and warehouse
--    stockouts have not yet been causally linked.
--
-- 8. Independent SQL-Python reconciliation
--    remains pending.
--
-- =========================================================
-- SECTION 06.3B STATUS:
-- VERIFIED
--
-- NEXT:
-- SECTION 06.4 - SUPPLIER-INVENTORY RISK & QA
-- =========================================================
-- =========================================================
-- SECTION 06.4A: SUPPLIER-LINKED INVENTORY RISK
-- =========================================================
--
-- BUSINESS QUESTION:
-- Are suppliers with weaker delivery reliability
-- associated with greater inventory risk?
--
-- PERIOD: October 2026
-- SOURCE: supply_chain_ai_db.inventory
--
-- OUTPUT: 12 supplier rows
--
-- IMPORTANT:
-- Association does not prove supplier causation.
-- No arbitrary composite risk score is used.
-- =========================================================

WITH supplier_october AS (

    SELECT
        supplier_id,

        COUNT(DISTINCT sku_id) AS distinct_skus,
        COUNT(*) AS inventory_locations,

        -- Known OTD delivery population
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_otd_events,

        -- Known on-time deliveries
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS on_time_events,

        -- Lead-time-eligible deliveries
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS eligible_lead_events,

        -- Weighted observed lead days
        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days IS NOT NULL
                THEN supplier_deliveries_count
                     * replenishment_lead_time_days
                ELSE 0
            END
        ) AS weighted_lead_days,

        -- Locations experiencing a stockout
        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS stockout_locations,

        -- Locations with zero closing stock
        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1 ELSE 0
            END
        ) AS zero_stock_locations,

        -- Positive stock below reorder point
        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS at_risk_locations,

        -- Unfulfilled customer demand
        SUM(demand_units - fulfilled_units)
            AS unfulfilled_units,

        -- Estimated potential gross-margin exposure
        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS potential_margin_exposure_inr

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

    GROUP BY supplier_id
),

-- =========================================================
-- STEP 2: SUPPLIER-SPECIFIC KPIs
-- =========================================================

supplier_kpis AS (

    SELECT
        supplier_october.*,

        eligible_otd_events - on_time_events
            AS late_delivery_events,

        -- Keep full precision for rankings
        on_time_events * 100.0 /
            NULLIF(eligible_otd_events, 0)
            AS supplier_otd_pct,

        weighted_lead_days * 1.0 /
            NULLIF(eligible_lead_events, 0)
            AS avg_lead_time_days,

        stockout_locations * 100.0 /
            NULLIF(inventory_locations, 0)
            AS stockout_rate_pct,

        at_risk_locations * 100.0 /
            NULLIF(inventory_locations, 0)
            AS at_risk_rate_pct

    FROM supplier_october
)

-- =========================================================
-- STEP 3: CONTRIBUTIONS AND INDEPENDENT RANKINGS
-- =========================================================

SELECT

    supplier_id,

    distinct_skus,
    inventory_locations,

    eligible_otd_events,
    late_delivery_events,

    ROUND(supplier_otd_pct, 2)
        AS supplier_otd_pct,

    ROUND(avg_lead_time_days, 2)
        AS avg_lead_time_days,

    stockout_locations,

    ROUND(stockout_rate_pct, 2)
        AS stockout_rate_pct,

    zero_stock_locations,

    at_risk_locations,

    ROUND(at_risk_rate_pct, 2)
        AS at_risk_rate_pct,

    unfulfilled_units,

    ROUND(potential_margin_exposure_inr, 2)
        AS potential_margin_exposure_inr,

    -- Share of portfolio's known late deliveries
    ROUND(
        late_delivery_events * 100.0 /
        NULLIF(
            SUM(late_delivery_events) OVER (),
            0
        ),
        2
    ) AS late_delivery_share_pct,

    -- Share of portfolio stockout locations
    ROUND(
        stockout_locations * 100.0 /
        NULLIF(
            SUM(stockout_locations) OVER (),
            0
        ),
        2
    ) AS stockout_share_pct,

    -- Share of portfolio's unfulfilled demand
    ROUND(
        unfulfilled_units * 100.0 /
        NULLIF(
            SUM(unfulfilled_units) OVER (),
            0
        ),
        2
    ) AS unfulfilled_share_pct,

    -- Share of potential margin exposure
    ROUND(
        potential_margin_exposure_inr * 100.0 /
        NULLIF(
            SUM(potential_margin_exposure_inr) OVER (),
            0
        ),
        2
    ) AS margin_exposure_share_pct,

    -- Lowest OTD = Rank 1
    DENSE_RANK() OVER (
        ORDER BY
            CASE
                WHEN supplier_otd_pct IS NULL
                THEN 1 ELSE 0
            END ASC,
            supplier_otd_pct ASC
    ) AS otd_risk_rank,

    -- Most stockout locations = Rank 1
    DENSE_RANK() OVER (
        ORDER BY stockout_locations DESC
    ) AS stockout_risk_rank,

    -- Highest potential financial exposure = Rank 1
    DENSE_RANK() OVER (
        ORDER BY potential_margin_exposure_inr DESC
    ) AS financial_exposure_rank

FROM supplier_kpis

ORDER BY supplier_id;
-- =========================================================
-- SECTION 06.4A: VERIFIED SUPPLIER-INVENTORY RISK
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
-- OUTPUT:
-- 12 Supplier Rows x 21 Columns
--
-- VALIDATION STATUS:
-- PASSED - Aggregates reconciled to Scripts 03,
-- 05, and verified October supplier metrics.
--
-- =========================================================
-- A. PORTFOLIO RECONCILIATION
-- =========================================================
--
-- Suppliers                        : 12
-- Distinct Supplier-Assigned SKUs   : 120
-- SKU-Warehouse Locations          : 360
--
-- Eligible OTD Events              : 729
-- Known Late Deliveries            : 83
--
-- Stockout Locations               : 79
-- Zero Closing Stock Locations     : 79
-- Positive-Stock At-Risk Locations : 141
--
-- Unfulfilled Demand Units         : 3681
--
-- Potential Gross-Margin Exposure:
-- 3071205.83 INR
--
-- All additive totals matched previously
-- verified October portfolio results.
--
-- IMPORTANT:
-- Equal aggregate stockout and zero-stock
-- counts do not prove identical affected rows.
--
-- =========================================================
-- B. VERIFIED SUPPLIER INVENTORY RESULTS
-- =========================================================
--
-- Supplier  Stockouts  At-Risk  Unfulfilled  Margin INR
--
-- SUP001        7         9        140       130180.84
-- SUP002        5        16         66        98725.60
-- SUP003        6        11        243       106164.38
-- SUP004        5        10        111        48700.94
-- SUP005       10        13       1012       952652.45
-- SUP006       10         9        757       345190.40
-- SUP007        5        16        176        37506.18
-- SUP008        5        16        119        41350.25
-- SUP009        5        13        151       111227.65
-- SUP010        6         9        345       286245.67
-- SUP011        6        10        331       504038.56
-- SUP012        9         9        230       409222.91
--
-- =========================================================
-- C. CONTRIBUTION RECONCILIATION
-- =========================================================
--
-- Displayed Late-Delivery Shares:
-- 99.98%
--
-- Displayed Stockout Shares:
-- 99.99%
--
-- Displayed Unfulfilled Demand Shares:
-- 99.99%
--
-- Displayed Potential Margin Exposure Shares:
-- 100.00%
--
-- NOTE:
-- Displayed totals differ slightly because
-- individual supplier percentages were
-- rounded to two decimal places.
--
-- Unrounded contribution totals equal 100%.
--
-- =========================================================
-- D. SUP005: GREATEST FINANCIAL EXPOSURE
-- =========================================================
--
-- October OTD                     : 87.72%
-- Weighted Lead Time              : 13.89 days
--
-- Stockout Locations              : 10
-- Stockout Rate                   : 33.33%
--
-- Unfulfilled Units               : 1012
--
-- Potential Margin Exposure:
-- 952652.45 INR
--
-- Share of Unfulfilled Demand:
-- 1012 / 3681 * 100 = 27.49%
--
-- Share of Potential Margin Exposure:
-- 952652.45 / 3071205.83 * 100
-- = 31.02%
--
-- OTD Risk Rank                   : 6
-- Stockout Risk Rank              : 1
-- Financial Exposure Rank         : 1
--
-- INTERPRETATION:
-- SUP005 has the highest associated stockout
-- count (tied with SUP006), most unfulfilled
-- units, and greatest potential margin exposure.
--
-- Investigate affected SKUs, inventory levels,
-- demand and replenishment requirements.
--
-- Supplier causation is not established.
--
-- =========================================================
-- E. SUP005 + SUP006: UNFULFILLED DEMAND
-- =========================================================
--
-- SUP005 Unfulfilled Units        : 1012
-- SUP006 Unfulfilled Units        : 757
--
-- Combined Unfulfilled Units:
-- 1012 + 757 = 1769
--
-- Portfolio Contribution:
-- 1769 / 3681 * 100
-- = 48.06%
--
-- Combined Stockout Locations:
-- 10 + 10 = 20
--
-- Stockout Contribution:
-- 20 / 79 * 100 = 25.32%
--
-- Combined Potential Margin Exposure:
-- 1297842.85 INR
--
-- Portfolio Financial Exposure Share:
-- 1297842.85 / 3071205.83 * 100
-- = 42.26%
--
-- BUSINESS IMPLICATION:
-- These two suppliers are associated with
-- a substantial concentration of unmet demand.
--
-- =========================================================
-- F. SUP007: POOR OTD, LIMITED FINANCIAL EXPOSURE
-- =========================================================
--
-- October OTD                     : 75.81%
-- Known Late Deliveries           : 15
--
-- Stockout Locations              : 5
-- Unfulfilled Units               : 176
--
-- Potential Margin Exposure:
-- 37506.18 INR
--
-- OTD Risk Rank                   : 1
-- Stockout Risk Rank              : 5
-- Financial Exposure Rank         : 12
--
-- INTERPRETATION:
-- SUP007 has the weakest observed October OTD
-- but the lowest associated potential financial
-- exposure among the twelve suppliers.
--
-- Supplier reliability and financial exposure
-- must therefore be evaluated separately.
--
-- =========================================================
-- G. SUP011: STRONG OTD, FINANCIAL EXPOSURE
-- =========================================================
--
-- October OTD                     : 100.00%
-- Known Late Deliveries           : 0
--
-- Stockout Locations              : 6
-- Unfulfilled Units               : 331
--
-- Potential Margin Exposure:
-- 504038.56 INR
--
-- Financial Exposure Rank         : 2
--
-- INTERPRETATION:
-- High observed delivery reliability does
-- not guarantee adequate inventory availability.
--
-- Demand planning and reorder settings are
-- possible investigation areas, not proven causes.
--
-- =========================================================
-- H. SUP012: FINANCIAL EXPOSURE
-- =========================================================
--
-- October OTD                     : 92.19%
-- Stockout Locations              : 9
-- Unfulfilled Units               : 230
--
-- Potential Margin Exposure:
-- 409222.91 INR
--
-- Financial Exposure Rank         : 3
--
-- INTERPRETATION:
-- Supplier-linked financial exposure can be
-- substantial even where OTD is relatively good.
--
-- =========================================================
-- I. PREVENTIVE REORDER RISK
-- =========================================================
--
-- SUP002 At-Risk Locations        : 16
-- SUP007 At-Risk Locations        : 16
-- SUP008 At-Risk Locations        : 16
--
-- Each Supplier At-Risk Rate:
-- 16 / 30 * 100 = 53.33%
--
-- Combined At-Risk Locations:
-- 48
--
-- Portfolio At-Risk Contribution:
-- 48 / 141 * 100 = 34.04%
--
-- INTERPRETATION:
-- These suppliers are associated with a
-- substantial share of positive-stock
-- locations below their reorder points.
--
-- This is a preventive investigation priority,
-- distinct from current stockout occurrence.
--
-- =========================================================
-- J. INDEPENDENT RISK RANKINGS
-- =========================================================
--
-- Supplier   OTD Rank   Stockout Rank   Financial Rank
--
-- SUP001        2              3               6
-- SUP002        8              5               9
-- SUP003        3              4               8
-- SUP004       11              5              10
-- SUP005        6              1               1
-- SUP006        5              1               4
-- SUP007        1              5              12
-- SUP008       10              5              11
-- SUP009        4              5               7
-- SUP010        9              4               5
-- SUP011       11              4               2
-- SUP012        7              2               3
--
-- DENSE_RANK() preserves equal rankings.
--
-- No artificial composite risk score is used.
--
-- =========================================================
-- K. BUSINESS INVESTIGATION PRIORITIES
-- =========================================================
--
-- DELIVERY RELIABILITY:
-- SUP003 (historical) and SUP007 (October)
--
-- CURRENT INVENTORY SHORTAGE EXPOSURE:
-- SUP005 and SUP006
--
-- POTENTIAL FINANCIAL EXPOSURE:
-- SUP005, SUP011 and SUP012
--
-- POSITIVE-STOCK REORDER RISK:
-- SUP002, SUP007 and SUP008
--
-- These investigation priorities address
-- different dimensions of supply chain risk.
--
-- =========================================================
-- L. LIMITATIONS
-- =========================================================
--
-- 1. Data represents a synthetic scenario.
--
-- 2. Supplier attribution follows the SKU's
--    supplier_id in the inventory dataset.
--
-- 3. Supplier-linked inventory outcomes do not
--    establish supplier-caused shortages.
--
-- 4. There are no individual delivery timestamps
--    linking a late shipment to a specific stockout.
--
-- 5. Financial exposure is estimated potential
--    gross margin, not confirmed lost profit.
--
-- 6. Positive-stock at-risk locations exclude
--    zero-closing-stock locations.
--
-- 7. October results do not independently
--    establish persistent inventory risk.
--
-- 8. Independent SQL-Python reconciliation
--    remains pending in Script 09.
--
-- =========================================================
-- SECTION 06.4A VALIDATION STATUS:
-- PASSED
--
-- NEXT:
-- SECTION 06.4B - FINAL SUPPLIER QA
-- =========================================================
-- =========================================================
-- SECTION 06.4B: FINAL SUPPLIER RECONCILIATION & QA
-- =========================================================
--
-- PROJECT: Supply Chain AI Control Tower
-- BUSINESS: NexaDistribution (Synthetic Scenario)
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- SOURCES:
-- supply_chain_ai_db.inventory
-- supply_chain_ai_db.suppliers
--
-- OBJECTIVE:
-- Reconcile supplier structure, delivery events,
-- October inventory risk and historical benchmarks.
--
-- OUTPUT:
-- Vertical metric | value report.
--
-- Final status must be PASS with zero failures.
-- =========================================================

WITH supplier_monthly AS (

    SELECT
        reporting_month,
        supplier_id,

        COUNT(*) AS location_records,

        COUNT(DISTINCT sku_id) AS sku_count,

        COUNT(DISTINCT warehouse) AS warehouse_count

    FROM supply_chain_ai_db.inventory

    GROUP BY reporting_month, supplier_id

),

monthly_coverage AS (

    SELECT
        reporting_month,
        COUNT(*) AS supplier_count

    FROM supplier_monthly

    GROUP BY reporting_month

),

structure_summary AS (

    SELECT
        COUNT(*) AS supplier_month_groups,

        SUM(
            CASE WHEN location_records <> 30
                 THEN 1 ELSE 0 END
        ) AS incorrect_location_groups,

        SUM(
            CASE WHEN sku_count <> 10
                 THEN 1 ELSE 0 END
        ) AS incorrect_sku_groups,

        SUM(
            CASE WHEN warehouse_count <> 3
                 THEN 1 ELSE 0 END
        ) AS incorrect_warehouse_groups

    FROM supplier_monthly

),

month_summary AS (

    SELECT
        SUM(
            CASE WHEN supplier_count <> 12
                 THEN 1 ELSE 0 END
        ) AS months_without_12_suppliers

    FROM monthly_coverage

),

supplier_dimension AS (

    SELECT
        COUNT(*) AS supplier_dimension_rows,

        COUNT(DISTINCT supplier_id)
            AS unique_dimension_suppliers

    FROM supply_chain_ai_db.suppliers

),

-- =========================================================
-- HISTORICAL SOURCE VALIDATION
-- =========================================================

historical AS (

    SELECT

        COUNT(*) AS source_rows,

        COUNT(DISTINCT reporting_month)
            AS reporting_months,

        MIN(reporting_month) AS first_month,
        MAX(reporting_month) AS last_month,

        COUNT(DISTINCT sku_id) AS distinct_skus,

        COUNT(DISTINCT warehouse)
            AS distinct_warehouses,

        COUNT(DISTINCT supplier_id)
            AS distinct_inventory_suppliers,

        COUNT(DISTINCT reporting_month, sku_id, warehouse)
            AS unique_inventory_grain,

        SUM(
            CASE
                WHEN reporting_month IS NULL
                  OR reporting_month < '2025-11-01'
                  OR reporting_month > '2026-10-01'
                THEN 1 ELSE 0
            END
        ) AS invalid_reporting_month_rows,

        SUM(
            CASE
                WHEN NOT EXISTS (
                    SELECT 1
                    FROM supply_chain_ai_db.suppliers s
                    WHERE s.supplier_id = i.supplier_id
                )
                THEN 1 ELSE 0
            END
        ) AS unmatched_supplier_rows,

        SUM(
            CASE
                WHEN supplier_deliveries_count IS NULL
                  OR supplier_deliveries_count < 0
                  OR supplier_on_time_deliveries_count < 0
                  OR supplier_on_time_deliveries_count >
                     supplier_deliveries_count
                  OR (
                      supplier_deliveries_count = 0
                      AND COALESCE(
                          supplier_on_time_deliveries_count, 0
                      ) <> 0
                  )
                THEN 1 ELSE 0
            END
        ) AS invalid_delivery_rows,

        SUM(
            CASE
                WHEN demand_units IS NULL
                  OR fulfilled_units IS NULL
                  OR demand_units < 0
                  OR fulfilled_units < 0
                  OR fulfilled_units > demand_units
                  OR closing_stock_units < 0
                  OR stockout_days < 0
                  OR unit_cost IS NULL
                  OR unit_selling_price IS NULL
                THEN 1 ELSE 0
            END
        ) AS invalid_inventory_rows,

        SUM(COALESCE(supplier_deliveries_count, 0))
            AS historical_delivery_events,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS historical_eligible_otd,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS historical_on_time,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                     - supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS historical_late,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS historical_unknown_otd,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS historical_eligible_lead,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS historical_unknown_lead

    FROM supply_chain_ai_db.inventory i

),

-- =========================================================
-- OCTOBER INVENTORY AND DELIVERY RECONCILIATION
-- =========================================================

october AS (

    SELECT

        COUNT(*) AS oct_source_rows,

        COUNT(DISTINCT supplier_id)
            AS oct_supplier_count,

        COUNT(DISTINCT sku_id)
            AS oct_sku_count,

        SUM(COALESCE(supplier_deliveries_count, 0))
            AS oct_delivery_events,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS oct_eligible_otd,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS oct_on_time,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NOT NULL
                THEN supplier_deliveries_count
                     - supplier_on_time_deliveries_count
                ELSE 0
            END
        ) AS oct_late,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND supplier_on_time_deliveries_count
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS oct_unknown_otd,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS oct_eligible_lead,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NULL
                THEN supplier_deliveries_count
                ELSE 0
            END
        ) AS oct_unknown_lead,

        SUM(
            CASE
                WHEN supplier_deliveries_count > 0
                 AND replenishment_lead_time_days
                     IS NOT NULL
                THEN replenishment_lead_time_days
                     * supplier_deliveries_count
                ELSE 0
            END
        ) AS oct_weighted_lead_days,

        SUM(
            CASE
                WHEN stockout_days > 0
                THEN 1 ELSE 0
            END
        ) AS oct_stockout_locations,

        SUM(
            CASE
                WHEN closing_stock_units = 0
                THEN 1 ELSE 0
            END
        ) AS oct_zero_stock_locations,

        SUM(
            CASE
                WHEN closing_stock_units > 0
                 AND closing_stock_units < reorder_point_units
                THEN 1 ELSE 0
            END
        ) AS oct_at_risk_locations,

        SUM(demand_units - fulfilled_units)
            AS oct_unfulfilled_units,

        SUM(
            (demand_units - fulfilled_units)
            * GREATEST(
                unit_selling_price - unit_cost,
                0
            )
        ) AS oct_margin_exposure

    FROM supply_chain_ai_db.inventory

    WHERE reporting_month = '2026-10-01'

),

-- =========================================================
-- COMBINE ALL RECONCILIATION MEASURES
-- =========================================================

metrics AS (

    SELECT
        h.*,
        o.*,
        ss.*,
        ms.*,
        sd.*

    FROM historical h

    CROSS JOIN october o

    CROSS JOIN structure_summary ss

    CROSS JOIN month_summary ms

    CROSS JOIN supplier_dimension sd

),

-- =========================================================
-- 31 EXPLICIT VALIDATION RULES
-- 0 = PASS, 1 = FAIL
-- =========================================================

validation_rules AS (

    SELECT 1 AS check_id,
           'Source row count' AS rule_name,
           IF(source_rows = 4320, 0, 1) AS failed
    FROM metrics

    UNION ALL
    SELECT 2, 'Reporting months and date range',
           IF(reporting_months = 12
              AND first_month = '2025-11-01'
              AND last_month = '2026-10-01', 0, 1)
    FROM metrics

    UNION ALL
    SELECT 3, 'Distinct SKU count',
           IF(distinct_skus = 120, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 4, 'Distinct warehouse count',
           IF(distinct_warehouses = 3, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 5, 'Inventory supplier count',
           IF(distinct_inventory_suppliers = 12, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 6, 'Supplier dimension uniqueness',
           IF(supplier_dimension_rows = 12
              AND unique_dimension_suppliers = 12, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 7, 'Supplier referential integrity',
           IF(unmatched_supplier_rows = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 8, 'Unique inventory grain',
           IF(unique_inventory_grain = source_rows, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 9, 'Supplier-month coverage',
           IF(supplier_month_groups = 144, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 10, '30 locations per supplier-month',
           IF(incorrect_location_groups = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 11, '10 SKUs per supplier-month',
           IF(incorrect_sku_groups = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 12, '3 warehouses per supplier-month',
           IF(incorrect_warehouse_groups = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 13, '12 suppliers in every month',
           IF(months_without_12_suppliers = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 14, 'Valid delivery counts',
           IF(invalid_delivery_rows = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 15, 'Valid inventory observations',
           IF(invalid_inventory_rows = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 16, 'Valid reporting-month values',
           IF(invalid_reporting_month_rows = 0, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 17, 'Historical delivery events',
           IF(historical_delivery_events = 8854, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 18, 'Historical eligible OTD events',
           IF(historical_eligible_otd = 8837, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 19, 'Historical on-time events',
           IF(historical_on_time = 7828, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 20, 'Historical unknown OTD events',
           IF(historical_unknown_otd = 17, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 21, 'Historical known late events',
           IF(historical_late = 1009, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 22, 'Historical lead-time eligibility',
           IF(historical_eligible_lead = 8823
              AND historical_unknown_lead = 31, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 23, 'Historical delivery reconciliation',
           IF(historical_on_time
              + historical_late
              + historical_unknown_otd
              = historical_delivery_events, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 24, 'October inventory structure',
           IF(oct_source_rows = 360
              AND oct_supplier_count = 12
              AND oct_sku_count = 120, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 25, 'October recorded deliveries',
           IF(oct_delivery_events = 730, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 26, 'October OTD reconciliation',
           IF(oct_eligible_otd = 729
              AND oct_on_time = 646
              AND oct_late = 83
              AND oct_unknown_otd = 1, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 27, 'October lead-time reconciliation',
           IF(oct_eligible_lead = 729
              AND oct_unknown_lead = 1
              AND oct_weighted_lead_days = 7920, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 28, 'October stockout and reorder risk',
           IF(oct_stockout_locations = 79
              AND oct_zero_stock_locations = 79
              AND oct_at_risk_locations = 141, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 29, 'October unfulfilled demand',
           IF(oct_unfulfilled_units = 3681, 0, 1)
    FROM metrics

    UNION ALL
    SELECT 30, 'October financial exposure',
           IF(
               ABS(oct_margin_exposure - 3071205.83) < 0.01,
               0, 1
           )
    FROM metrics

    UNION ALL
    SELECT 31, 'October delivery event balance',
           IF(
               oct_on_time + oct_late + oct_unknown_otd
               = oct_delivery_events,
               0, 1
           )
    FROM metrics
),

qa_status AS (

    SELECT
        COUNT(*) AS checks_run,

        SUM(failed) AS failed_checks,

        COALESCE(
            GROUP_CONCAT(
                CASE WHEN failed = 1
                     THEN rule_name
                     ELSE NULL
                END
                ORDER BY check_id
                SEPARATOR '; '
            ),
            'None'
        ) AS failed_rule_names

    FROM validation_rules

),

-- =========================================================
-- ORDERED METRIC LABELS FOR VERTICAL OUTPUT
-- =========================================================

display_metrics AS (

    SELECT 1 AS seq, 'Source Inventory Records' AS metric
    UNION ALL SELECT 2, 'Reporting Months'
    UNION ALL SELECT 3, 'First Reporting Month'
    UNION ALL SELECT 4, 'Last Reporting Month'
    UNION ALL SELECT 5, 'Distinct SKUs'
    UNION ALL SELECT 6, 'Distinct Warehouses'
    UNION ALL SELECT 7, 'Inventory Supplier IDs'
    UNION ALL SELECT 8, 'Supplier Dimension Rows'
    UNION ALL SELECT 9, 'Unique Dimension Supplier IDs'
    UNION ALL SELECT 10, 'Supplier-Month Groups'
    UNION ALL SELECT 11, 'Incorrect 30-Location Groups'
    UNION ALL SELECT 12, 'Incorrect 10-SKU Groups'
    UNION ALL SELECT 13, 'Incorrect 3-Warehouse Groups'
    UNION ALL SELECT 14, 'Months Without 12 Suppliers'
    UNION ALL SELECT 15, 'Unmatched Supplier References'
    UNION ALL SELECT 16, 'Duplicate Inventory Grain Records'
    UNION ALL SELECT 17, 'Invalid Delivery Records'
    UNION ALL SELECT 18, 'Invalid Inventory Records'
    UNION ALL SELECT 19, 'Invalid Reporting Month Records'
    UNION ALL SELECT 20, 'Historical Recorded Deliveries'
    UNION ALL SELECT 21, 'Historical Eligible OTD Deliveries'
    UNION ALL SELECT 22, 'Historical On-Time Deliveries'
    UNION ALL SELECT 23, 'Historical Late Deliveries'
    UNION ALL SELECT 24, 'Historical Unknown OTD Events'
    UNION ALL SELECT 25, 'Historical Eligible Lead-Time Events'
    UNION ALL SELECT 26, 'Historical Unknown Lead-Time Events'
    UNION ALL SELECT 27, 'Historical Portfolio OTD (%)'
    UNION ALL SELECT 28, 'October Inventory Locations'
    UNION ALL SELECT 29, 'October Recorded Deliveries'
    UNION ALL SELECT 30, 'October Eligible OTD Deliveries'
    UNION ALL SELECT 31, 'October On-Time Deliveries'
    UNION ALL SELECT 32, 'October Late Deliveries'
    UNION ALL SELECT 33, 'October Unknown OTD Events'
    UNION ALL SELECT 34, 'October Eligible Lead-Time Events'
    UNION ALL SELECT 35, 'October Unknown Lead-Time Events'
    UNION ALL SELECT 36, 'October Weighted Lead Days'
    UNION ALL SELECT 37, 'October Portfolio OTD (%)'
    UNION ALL SELECT 38, 'October Average Lead Time (Days)'
    UNION ALL SELECT 39, 'October Stockout Locations'
    UNION ALL SELECT 40, 'October Zero-Stock Locations'
    UNION ALL SELECT 41, 'October At-Risk Locations'
    UNION ALL SELECT 42, 'October Unfulfilled Units'
    UNION ALL SELECT 43, 'October Potential Margin Exposure (INR)'
    UNION ALL SELECT 44, 'QA Validation Rules Executed'
    UNION ALL SELECT 45, 'Failed QA Rules'
    UNION ALL SELECT 46, 'Failed Rule Names'
    UNION ALL SELECT 47, 'Overall Supplier QA Status'

)

-- =========================================================
-- FINAL VERTICAL QA RESULT: METRIC | VALUE
-- =========================================================

SELECT

    d.metric,

    CASE d.seq

        WHEN 1 THEN CAST(m.source_rows AS CHAR)
        WHEN 2 THEN CAST(m.reporting_months AS CHAR)
        WHEN 3 THEN CAST(m.first_month AS CHAR)
        WHEN 4 THEN CAST(m.last_month AS CHAR)
        WHEN 5 THEN CAST(m.distinct_skus AS CHAR)
        WHEN 6 THEN CAST(m.distinct_warehouses AS CHAR)
        WHEN 7 THEN CAST(m.distinct_inventory_suppliers AS CHAR)
        WHEN 8 THEN CAST(m.supplier_dimension_rows AS CHAR)
        WHEN 9 THEN CAST(m.unique_dimension_suppliers AS CHAR)
        WHEN 10 THEN CAST(m.supplier_month_groups AS CHAR)
        WHEN 11 THEN CAST(m.incorrect_location_groups AS CHAR)
        WHEN 12 THEN CAST(m.incorrect_sku_groups AS CHAR)
        WHEN 13 THEN CAST(m.incorrect_warehouse_groups AS CHAR)
        WHEN 14 THEN CAST(m.months_without_12_suppliers AS CHAR)
        WHEN 15 THEN CAST(m.unmatched_supplier_rows AS CHAR)

        WHEN 16 THEN CAST(
            m.source_rows - m.unique_inventory_grain
            AS CHAR
        )

        WHEN 17 THEN CAST(m.invalid_delivery_rows AS CHAR)
        WHEN 18 THEN CAST(m.invalid_inventory_rows AS CHAR)
        WHEN 19 THEN CAST(m.invalid_reporting_month_rows AS CHAR)

        WHEN 20 THEN CAST(m.historical_delivery_events AS CHAR)
        WHEN 21 THEN CAST(m.historical_eligible_otd AS CHAR)
        WHEN 22 THEN CAST(m.historical_on_time AS CHAR)
        WHEN 23 THEN CAST(m.historical_late AS CHAR)
        WHEN 24 THEN CAST(m.historical_unknown_otd AS CHAR)
        WHEN 25 THEN CAST(m.historical_eligible_lead AS CHAR)
        WHEN 26 THEN CAST(m.historical_unknown_lead AS CHAR)

        WHEN 27 THEN CAST(
            ROUND(
                m.historical_on_time * 100.0 /
                NULLIF(m.historical_eligible_otd, 0),
                2
            ) AS CHAR
        )

        WHEN 28 THEN CAST(m.oct_source_rows AS CHAR)
        WHEN 29 THEN CAST(m.oct_delivery_events AS CHAR)
        WHEN 30 THEN CAST(m.oct_eligible_otd AS CHAR)
        WHEN 31 THEN CAST(m.oct_on_time AS CHAR)
        WHEN 32 THEN CAST(m.oct_late AS CHAR)
        WHEN 33 THEN CAST(m.oct_unknown_otd AS CHAR)
        WHEN 34 THEN CAST(m.oct_eligible_lead AS CHAR)
        WHEN 35 THEN CAST(m.oct_unknown_lead AS CHAR)
        WHEN 36 THEN CAST(m.oct_weighted_lead_days AS CHAR)

        WHEN 37 THEN CAST(
            ROUND(
                m.oct_on_time * 100.0 /
                NULLIF(m.oct_eligible_otd, 0),
                2
            ) AS CHAR
        )

        WHEN 38 THEN CAST(
            ROUND(
                m.oct_weighted_lead_days * 1.0 /
                NULLIF(m.oct_eligible_lead, 0),
                2
            ) AS CHAR
        )

        WHEN 39 THEN CAST(m.oct_stockout_locations AS CHAR)
        WHEN 40 THEN CAST(m.oct_zero_stock_locations AS CHAR)
        WHEN 41 THEN CAST(m.oct_at_risk_locations AS CHAR)
        WHEN 42 THEN CAST(m.oct_unfulfilled_units AS CHAR)

        WHEN 43 THEN CAST(
            ROUND(m.oct_margin_exposure, 2) AS CHAR
        )

        WHEN 44 THEN CAST(q.checks_run AS CHAR)
        WHEN 45 THEN CAST(q.failed_checks AS CHAR)
        WHEN 46 THEN q.failed_rule_names

        WHEN 47 THEN
            CASE
                WHEN q.checks_run = 31
                 AND q.failed_checks = 0
                THEN 'PASS'
                ELSE 'FAIL'
            END

    END AS value

FROM display_metrics d

CROSS JOIN metrics m
CROSS JOIN qa_status q

ORDER BY d.seq;
-- =========================================================
-- SECTION 06.4B: FINAL SUPPLIER RECONCILIATION
--              & QUALITY ASSURANCE
-- =========================================================
--
-- PROJECT:
-- Supply Chain AI Control Tower
--
-- BUSINESS:
-- NexaDistribution (Synthetic Scenario)
--
-- SOURCE TABLES:
-- supply_chain_ai_db.inventory
-- supply_chain_ai_db.suppliers
--
-- REPORTING PERIOD:
-- November 2025 through October 2026
--
-- EXECUTION STATUS:
-- VERIFIED
--
-- TOTAL QA VALIDATION RULES: 31
-- PASSED: 31
-- FAILED: 0
--
-- OVERALL SUPPLIER QA STATUS: PASS
--
-- =========================================================
-- A. SOURCE DATA STRUCTURE
-- =========================================================
--
-- Source Inventory Records           : 4320
-- Reporting Months                   : 12
-- First Reporting Month              : 2025-11-01
-- Last Reporting Month               : 2026-10-01
--
-- Distinct SKUs                      : 120
-- Distinct Warehouses                : 3
-- Inventory Supplier IDs             : 12
--
-- Supplier Dimension Rows            : 12
-- Unique Dimension Supplier IDs      : 12
--
-- Supplier-Month Groups              : 144
--
-- Expected Structure:
-- 12 suppliers x 12 months = 144 groups
--
-- Each Supplier-Month:
-- 10 SKUs x 3 warehouses = 30 records
--
-- Expected Inventory Records:
-- 144 x 30 = 4320
--
-- STRUCTURAL VALIDATION: PASSED
--
-- =========================================================
-- B. DATA QUALITY & INTEGRITY
-- =========================================================
--
-- Incorrect 30-Location Groups       : 0
-- Incorrect 10-SKU Groups            : 0
-- Incorrect 3-Warehouse Groups       : 0
-- Months Without 12 Suppliers        : 0
--
-- Unmatched Supplier References      : 0
-- Duplicate Inventory Grain Records  : 0
--
-- Invalid Delivery Records           : 0
-- Invalid Inventory Records          : 0
-- Invalid Reporting Month Records    : 0
--
-- All corresponding QA rules passed.
--
-- =========================================================
-- C. HISTORICAL DELIVERY RECONCILIATION
-- =========================================================
--
-- Historical Recorded Deliveries     : 8854
--
-- Historical Eligible OTD Deliveries : 8837
-- Historical On-Time Deliveries      : 7828
-- Historical Late Deliveries         : 1009
-- Historical Unknown OTD Events      : 17
--
-- Delivery Reconciliation:
-- 7828 + 1009 + 17 = 8854
--
-- Historical Portfolio OTD:
-- 7828 / 8837 * 100
-- = 88.58%
--
-- Historical Eligible Lead-Time Events:
-- 8823
--
-- Historical Unknown Lead-Time Events:
-- 31
--
-- Lead-Time Eligibility Reconciliation:
-- 8823 + 31 = 8854
--
-- IMPORTANT:
-- OTD and observed lead-time calculations
-- use separate eligibility conditions.
--
-- Missing outcomes are excluded from their
-- corresponding KPI denominator.
--
-- HISTORICAL DELIVERY VALIDATION: PASSED
--
-- =========================================================
-- D. OCTOBER 2026 DELIVERY RECONCILIATION
-- =========================================================
--
-- October Inventory Locations        : 360
-- October Recorded Deliveries        : 730
--
-- October Eligible OTD Deliveries    : 729
-- October On-Time Deliveries         : 646
-- October Late Deliveries            : 83
-- October Unknown OTD Events         : 1
--
-- October Delivery Reconciliation:
-- 646 + 83 + 1 = 730
--
-- October Supplier OTD:
-- 646 / 729 * 100
-- = 88.61%
--
-- October Eligible Lead-Time Events  : 729
-- October Unknown Lead-Time Events   : 1
--
-- October Weighted Lead Days         : 7920
--
-- October Weighted Average Lead Time:
-- 7920 / 729
-- = 10.86 days
--
-- OCTOBER DELIVERY VALIDATION: PASSED
--
-- =========================================================
-- E. OCTOBER INVENTORY RECONCILIATION
-- =========================================================
--
-- October Stockout Locations         : 79
-- October Zero-Stock Locations       : 79
-- October Positive-Stock At-Risk     : 141
--
-- October Unfulfilled Units          : 3681
--
-- October Potential Gross-Margin Exposure:
-- INR 3071205.83
--
-- These values match the previously verified
-- October company KPI and warehouse analyses.
--
-- IMPORTANT:
-- Stockout occurrence and zero closing stock
-- are different measures, even when their
-- aggregated counts are equal.
--
-- Potential gross-margin exposure represents
-- an estimate, not confirmed realized loss.
--
-- OCTOBER INVENTORY VALIDATION: PASSED
--
-- =========================================================
-- F. VALIDATION RULE RESULTS
-- =========================================================
--
-- 01. Source row count                 PASS
-- 02. Reporting months/date range      PASS
-- 03. Distinct SKU count               PASS
-- 04. Distinct warehouse count         PASS
-- 05. Inventory supplier count         PASS
-- 06. Supplier dimension uniqueness    PASS
-- 07. Supplier referential integrity   PASS
-- 08. Unique inventory grain           PASS
-- 09. Supplier-month coverage          PASS
-- 10. 30 locations per group           PASS
-- 11. 10 SKUs per group                PASS
-- 12. 3 warehouses per group           PASS
-- 13. 12 suppliers in every month      PASS
-- 14. Valid delivery counts            PASS
-- 15. Valid inventory observations     PASS
-- 16. Valid reporting-month values     PASS
--
-- 17. Historical delivery events       PASS
-- 18. Historical eligible OTD events   PASS
-- 19. Historical on-time events        PASS
-- 20. Historical unknown OTD events    PASS
-- 21. Historical known late events     PASS
-- 22. Historical lead-time eligibility PASS
-- 23. Historical delivery balance      PASS
--
-- 24. October inventory structure      PASS
-- 25. October recorded deliveries      PASS
-- 26. October OTD reconciliation       PASS
-- 27. October lead-time reconciliation PASS
-- 28. October stockout/reorder risk    PASS
-- 29. October unfulfilled demand       PASS
-- 30. October financial exposure       PASS
-- 31. October delivery event balance   PASS
--
-- =========================================================
-- G. FINAL QA REPORT
-- =========================================================
--
-- QA Metric Rows Returned             : 47
--
-- QA Validation Rules Executed        : 31
-- Failed QA Rules                     : 0
-- Failed Rule Names                   : None
--
-- Overall Supplier QA Status          : PASS
--
-- All 31 database validation rules passed.
--
-- =========================================================
-- H. COMPLETED SUPPLIER INVESTIGATION
-- =========================================================
--
-- SECTION 06.1:
-- October Supplier KPI Scorecard
-- VERIFIED
--
-- SECTION 06.2:
-- Supplier Reliability Rankings &
-- Late-Delivery Contribution
-- VERIFIED
--
-- SECTION 06.3A:
-- Twelve-Month Supplier Summary
-- VERIFIED
--
-- SECTION 06.3B:
-- Monthly Supplier Reliability &
-- Lead-Time Trends
-- VERIFIED
--
-- SECTION 06.4A:
-- Supplier-Linked Inventory Risk
-- VERIFIED
--
-- SECTION 06.4B:
-- Final Supplier Reconciliation & QA
-- VERIFIED
--
-- =========================================================
-- I. KEY BUSINESS FINDINGS
-- =========================================================
--
-- 1. SUP003:
-- Lowest 12-month weighted OTD at 75.11%.
-- Below portfolio OTD in all twelve months.
--
-- 2. SUP007:
-- Lowest October OTD at 75.81%.
-- Highest October known late deliveries: 15.
--
-- 3. SUP009:
-- Longest historical weighted lead time:
-- 13.77 days.
--
-- 4. SUP005:
-- Longest October weighted lead time:
-- 13.89 days.
--
-- Highest October potential margin exposure:
-- INR 952652.45.
--
-- 5. SUP005 and SUP006:
-- Combined unfulfilled demand: 1769 units.
-- Share of October unmet demand: 48.06%.
--
-- 6. SUP011:
-- Achieved 100% observed October OTD,
-- yet associated inventory recorded
-- INR 504038.56 potential margin exposure.
--
-- INTERPRETATION:
-- Supplier reliability, stock availability,
-- and financial exposure are distinct measures.
--
-- Supplier-linked inventory risk does not
-- establish that late deliveries caused
-- the observed stockouts.
--
-- =========================================================
-- J. ANALYTICAL LIMITATIONS
-- =========================================================
--
-- 1. Dataset represents a synthetic business.
--
-- 2. Delivery observations are aggregated.
--
-- 3. Unknown outcomes remain excluded from
--    relevant eligible delivery populations.
--
-- 4. Observed lead time is not necessarily
--    a contractual delivery delay.
--
-- 5. Supplier-linked shortages do not
--    establish supplier causation.
--
-- 6. Potential gross-margin exposure is an
--    estimate, not actual lost profit.
--
-- 7. These checks verify database structure
--    and specified numerical benchmarks.
--
-- 8. Independent cleaned-CSV versus SQL
--    reconciliation is still pending
--    in Script 09.
--
-- =========================================================
-- FINAL SCRIPT 06 STATUS:
-- SQL ANALYSIS AND DATABASE QA COMPLETE
--
-- NEXT SCRIPT:
-- 07_inventory_risk_analysis.sql
-- =========================================================