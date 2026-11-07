# Business Requirements — Draft approved v1.0

**Project:** Project 02 — Supply Chain & Inventory AI Control Tower  
**Business:** NexaDistribution, fictional Indian retail distribution business  
**Source:** Two **synthetic**, intentionally messy CSVs  
**Coverage:** Nov 2025–Oct 2026; 120 products; 3 warehouses (North, South, West); 12 suppliers

## Problem and purpose
Inventory shortages, uneven supplier on-time delivery, long lead times and excess stock make it hard to prioritize replenishment. Deliver one reproducible Power BI + LangGraph analytical control tower to identify and investigate material risk with verified evidence.

## Users
Supply Chain Director, Procurement Manager, Inventory Planning Manager, Warehouse Operations Managers, Finance Manager.

## Six questions
1. Which SKU–warehouse locations are stockout-prone?
2. Which suppliers are behind lead-time and punctuality targets?
3. Where is inventory under- or overstocked?
4. How do supplier delivery outcomes coincide with fulfillment?
5. What is potential operational and gross-margin exposure?
6. Which evidence-backed corrective actions should be prioritized?

## Ten operational KPIs
1. **Fill rate** = sum(fulfilled units) / sum(demand units), for records with positive demand.
2. **Monthly stockout occurrence rate** = SKU–warehouse–month records with `stockout_days > 0` / all eligible SKU–warehouse–month records, explicitly distinct from the point-in-time zero-stock location rate.
3. **Month-end at-risk locations** = count of SKU–warehouse combinations with `0 < closing_stock_units < reorder_point_units` in a selected month.
4. **On-time delivery percentage** = sum(on-time replenishment delivery lines) / sum(all replenishment delivery lines); do not average percentages naively.
5. **Observed replenishment lead time** = sum(observed lead-time days × delivery-line count) / sum(delivery-line counts for rows with measured lead time).
6. **Closing inventory value** = sum(month-end closing units × unit cost) for the selected month; do not sum stock balances across months.
7. **Days inventory coverage** = month-end closing stock / (selected month's demand / days in month) where demand is positive.
8. **Inventory turnover (period)** = fulfilled units valued at recorded unit cost during period / average of monthly closing inventory cost values during that period. Proxy: cannot measure exact COGS without adjustments and beginning valuations.
9. **Unfulfilled demand** = sum(demand - fulfilled units); nonnegative.
10. **Potential gross-margin exposure** = sum(unfulfilled units × (unit selling price - unit cost)); scenario only, not verified lost profit.

## Data rules
Base grain: SKU × warehouse × reporting month. Each SKU uses one reference supplier across periods. Supplier data has one unique record per supplier **after cleaning**. Underlying synthetic inventory balances reconcile, and month opening matches preceding month closing before deliberate defects. Source errors are never silently overwritten; quarantine irreparable rows. A customer order demand model, actual sales returns, purchase-order promises, and costs beyond unit costs are out of scope.

## Visual requirements
Two-page Power BI report with warehouse/supplier/category/date slicers, metric selection using Field Parameters, year/quarter/month drill-down, conditional KPI status colors, and demand-growth what-if parameter. Additional Power BI parameter/helper tables are derived metadata, not external source CSV datasets.

## AI requirements
Real four-node LangGraph StateGraph: detect → investigate → LLM analysis → recommendations and numeric-validation checks. Structured output for Power BI. Evidence, caveats, prioritized actions, owners, and monitoring KPIs.

## Success criteria
Cleaning audit and recorded defects, SQL/Python KPI reconciliation, working dynamic report, LangGraph execution and grounded outputs, no credentials committed, reproducible GitHub project.
