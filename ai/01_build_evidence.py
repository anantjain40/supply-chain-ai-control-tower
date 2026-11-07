from pathlib import Path
import json
import pandas as pd

# ==================================================
# 1. FILE PATHS
# ==================================================

ROOT = Path(__file__).resolve().parents[1]

INVENTORY_FILE = ROOT / "output" / "inventory_clean.csv"
SUPPLIERS_FILE = ROOT / "output" / "suppliers_clean.csv"

OUTPUT_FILE = ROOT / "output" / "ai_evidence_oct2026.json"

REPORTING_MONTH = "2026-10"


# ==================================================
# 2. LOAD AND VALIDATE CLEANED DATA
# ==================================================

inventory = pd.read_csv(INVENTORY_FILE)
suppliers = pd.read_csv(SUPPLIERS_FILE)

inventory["reporting_month"] = pd.to_datetime(
    inventory["reporting_month"]
)

required_columns = [
    "sku_id",
    "product_name",
    "category",
    "warehouse",
    "supplier_id",
    "reporting_month",
    "opening_stock_units",
    "received_units",
    "demand_units",
    "fulfilled_units",
    "closing_stock_units",
    "reorder_point_units",
    "unit_cost",
    "unit_selling_price",
    "supplier_deliveries_count",
    "supplier_on_time_deliveries_count",
    "replenishment_lead_time_days",
    "days_in_month",
    "stockout_days",
    "unfulfilled_units",
    "fulfilled_cogs_proxy",
    "closing_inventory_value",
    "potential_margin_exposure",
    "inventory_status",
]

missing = set(required_columns) - set(inventory.columns)

if missing:
    raise ValueError(f"Missing inventory columns: {missing}")

if len(inventory) != 4320:
    raise ValueError("Inventory record count is incorrect.")

if len(suppliers) != 12:
    raise ValueError("Supplier record count is incorrect.")

if inventory.duplicated(
    ["sku_id", "warehouse", "reporting_month"]
).any():
    raise ValueError("Duplicate SKU-warehouse-month keys.")

unmatched = (
    set(inventory["supplier_id"])
    - set(suppliers["supplier_id"])
)

if unmatched:
    raise ValueError(f"Unmatched suppliers: {unmatched}")

print("DATA QUALITY: PASSED")


# ==================================================
# 3. REUSABLE BUSINESS KPI CALCULATIONS
# ==================================================

def calculate_kpis(df):

    demand = df["demand_units"].sum()
    fulfilled = df["fulfilled_units"].sum()
    unfulfilled = df["unfulfilled_units"].sum()

    locations = len(df)

    closing = df["closing_stock_units"]
    reorder = df["reorder_point_units"]

    stockout_locations = (
    df["stockout_days"] > 0
).sum()

    at_risk_locations = (
        (closing > 0) & (closing < reorder)
    ).sum()

    # Exclude unknown on-time outcomes.
    valid_otd = (
        df["supplier_on_time_deliveries_count"].notna()
        & (df["supplier_deliveries_count"] > 0)
    )

    eligible_deliveries = df.loc[
        valid_otd, "supplier_deliveries_count"
    ].sum()

    on_time_deliveries = df.loc[
        valid_otd, "supplier_on_time_deliveries_count"
    ].sum()

    # Delivery-count-weighted lead time.
    valid_lead = (
        df["replenishment_lead_time_days"].notna()
        & (df["supplier_deliveries_count"] > 0)
    )

    lead_df = df.loc[valid_lead]

    lead_delivery_count = (
        lead_df["supplier_deliveries_count"].sum()
    )

    weighted_lead_days = (
        lead_df["replenishment_lead_time_days"]
        * lead_df["supplier_deliveries_count"]
    ).sum()

    opening_value = (
        df["opening_stock_units"] * df["unit_cost"]
    ).sum()

    closing_value = df["closing_inventory_value"].sum()

    average_inventory_value = (
        opening_value + closing_value
    ) / 2

    fulfilled_cogs = df["fulfilled_cogs_proxy"].sum()

    selling_exposure = (
        df["unfulfilled_units"]
        * df["unit_selling_price"]
    ).sum()

    margin_exposure = (
        df["unfulfilled_units"]
        * (
            df["unit_selling_price"]
            - df["unit_cost"]
        )
    ).sum()

    days = df["days_in_month"].max()

    def safe_divide(a, b):
        return float(a / b) if b else 0.0

    return {
        "locations": int(locations),
        "demand_units": int(demand),
        "fulfilled_units": int(fulfilled),
        "unfulfilled_units": int(unfulfilled),
        "stockout_locations": int(stockout_locations),
        "at_risk_locations": int(at_risk_locations),
        "eligible_on_time_deliveries": int(eligible_deliveries),
        "on_time_deliveries": int(on_time_deliveries),
        "eligible_lead_time_deliveries": int(lead_delivery_count),
        "weighted_lead_days": round(
            float(weighted_lead_days), 2
        ),
        "fill_rate_pct": round(
            safe_divide(fulfilled, demand) * 100, 2
        ),
        "stockout_rate_pct": round(
            safe_divide(stockout_locations, locations) * 100, 2
        ),
        "at_risk_rate_pct": round(
            safe_divide(at_risk_locations, locations) * 100, 2
        ),
        "supplier_on_time_rate_pct": round(
            safe_divide(on_time_deliveries, eligible_deliveries)
            * 100, 2
        ),
        "weighted_lead_time_days": round(
            safe_divide(weighted_lead_days, lead_delivery_count), 2
        ),
        "closing_inventory_value": round(
            float(closing_value), 2
        ),
        "inventory_coverage_days": round(
            safe_divide(closing.sum() * days, demand), 2
        ),
        "inventory_turnover": round(
            safe_divide(fulfilled_cogs, average_inventory_value), 2
        ),
        "potential_unmet_sales": round(
            float(selling_exposure), 2
        ),
        "potential_gross_margin_exposure": round(
            float(margin_exposure), 2
        ),
    }


# ==================================================
# 4. OCTOBER KPI VERIFICATION
# ==================================================

october = inventory.loc[
    inventory["reporting_month"].dt.strftime("%Y-%m")
    == REPORTING_MONTH
].copy()

if len(october) != 360:
    raise ValueError("October should contain 360 records.")

october_kpis = calculate_kpis(october)

sql_benchmarks = {
    "fill_rate_pct": 92.87,
    "stockout_rate_pct": 21.94,
    "at_risk_rate_pct": 39.17,
    "supplier_on_time_rate_pct": 88.61,
    "weighted_lead_time_days": 10.86,
    "closing_inventory_value": 58027088.73,
    "inventory_coverage_days": 19.13,
    "inventory_turnover": 1.45,
    "potential_unmet_sales": 9356605.50,
    "potential_gross_margin_exposure": 3071205.83,
}

verification = {}

for metric, expected in sql_benchmarks.items():

    actual = october_kpis[metric]

    tolerance = 1.0 if expected > 1000 else 0.01

    passed = abs(actual - expected) <= tolerance

    verification[metric] = {
        "expected": expected,
        "actual": actual,
        "passed": bool(passed),
    }

    print(
        f"{metric}: "
        f"{'PASS' if passed else 'FAIL'} "
        f"(actual={actual}, expected={expected})"
    )

passed_count = sum(
    result["passed"] for result in verification.values()
)

print(f"\nOCTOBER KPI QA: {passed_count}/10 PASSED")

if passed_count != 10:
    raise ValueError(
        "KPI reconciliation failed. Investigate before AI analysis."
    )


# ==================================================
# 5. MONTHLY PERFORMANCE TRENDS
# ==================================================

monthly_trends = []

for month, group in inventory.groupby("reporting_month"):

    monthly_trends.append({
        "month": month.strftime("%Y-%m"),
        **calculate_kpis(group),
    })


# ==================================================
# 6. WAREHOUSE AND CATEGORY INVESTIGATIONS
# ==================================================

warehouse_results = []

for warehouse, group in october.groupby("warehouse"):

    warehouse_results.append({
        "warehouse": warehouse,
        **calculate_kpis(group),
    })

warehouse_results.sort(
    key=lambda x: x["potential_gross_margin_exposure"],
    reverse=True,
)

category_warehouse_results = []

for (category, warehouse), group in october.groupby(
    ["category", "warehouse"]
):

    category_warehouse_results.append({
        "category": category,
        "warehouse": warehouse,
        **calculate_kpis(group),
    })

category_warehouse_results.sort(
    key=lambda x: x["potential_gross_margin_exposure"],
    reverse=True,
)


# ==================================================
# 7. SUPPLIER PERFORMANCE RANKING
# ==================================================

supplier_data = october.merge(
    suppliers[["supplier_id", "supplier_name"]],
    on="supplier_id",
    how="left",
    validate="many_to_one",
)

supplier_results = []

for (supplier_id, supplier_name), group in supplier_data.groupby(
    ["supplier_id", "supplier_name"]
):

    metrics = calculate_kpis(group)

    supplier_results.append({
        "supplier_id": supplier_id,
        "supplier_name": supplier_name,
        "on_time_rate_pct": metrics["supplier_on_time_rate_pct"],
        "eligible_deliveries": metrics[
            "eligible_on_time_deliveries"
        ],
        "on_time_deliveries": metrics["on_time_deliveries"],
        "weighted_lead_time_days": metrics[
            "weighted_lead_time_days"
        ],
        "potential_gross_margin_exposure": metrics[
            "potential_gross_margin_exposure"
        ],
    })

supplier_results.sort(
    key=lambda x: x["on_time_rate_pct"]
)


# ==================================================
# 8. TOP CRITICAL / AT-RISK SKU LOCATIONS
# ==================================================

risk_data = october.loc[
    october["inventory_status"].isin([
        "Critical: Zero Stock",
        "At Risk: Below ROP",
    ])
].copy()

risk_data["calculated_margin_exposure"] = (
    risk_data["unfulfilled_units"]
    * (
        risk_data["unit_selling_price"]
        - risk_data["unit_cost"]
    )
).round(2)

risk_data = risk_data.sort_values(
    "calculated_margin_exposure",
    ascending=False,
)

risk_columns = [
    "sku_id",
    "product_name",
    "category",
    "warehouse",
    "supplier_id",
    "inventory_status",
    "closing_stock_units",
    "reorder_point_units",
    "unfulfilled_units",
    "calculated_margin_exposure",
]

top_risk_locations = risk_data[
    risk_columns
].head(20).to_dict(orient="records")


# ==================================================
# 9. BUILD STRUCTURED EVIDENCE
# ==================================================

evidence = {
    "project": "Supply Chain AI Control Tower",
    "reporting_month": REPORTING_MONTH,
        "currency": "INR",
    "currency_symbol": "₹",
    "data_type": "Synthetic project data",
    "source_files": [
        "output/inventory_clean.csv",
        "output/suppliers_clean.csv",
    ],
    "source_record_counts": {
        "inventory": len(inventory),
        "suppliers": len(suppliers),
        "october_inventory": len(october),
    },
    "october_kpis": october_kpis,
    "sql_benchmark_verification": verification,
    "monthly_trends": monthly_trends,
    "warehouse_performance": warehouse_results,
    "category_warehouse_priorities": category_warehouse_results,
    "supplier_performance": supplier_results,
    "top_risk_sku_locations": top_risk_locations,
    "business_rules": {
        "stockout": "Stockout days greater than zero during the reporting month.",
        "at_risk": (
            "Closing stock is positive and below reorder point."
        ),
        "supplier_on_time": (
            "Unknown on-time outcomes excluded from denominator."
        ),
        "lead_time": (
            "Observed lead time weighted by supplier delivery count."
        ),
        "financial_exposure": (
            "Potential gross margin associated with unfulfilled demand."
        ),
    },
    "limitations": [
        "Dataset is synthetic.",
        "Financial exposure is potential, not realized loss.",
        "Observed correlations do not prove root causes.",
        "Supplier on-time and lead-time missing values require exclusions.",
        "Recommendations require business validation before execution.",
    ],
}

OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

with open(OUTPUT_FILE, "w", encoding="utf-8") as file:
    json.dump(evidence, file, indent=2, ensure_ascii=False)

print("\nAI EVIDENCE GENERATION SUCCESSFUL")
print(f"Output: {OUTPUT_FILE}")
print(f"Monthly periods: {len(monthly_trends)}")
print(f"Warehouses: {len(warehouse_results)}")
print(f"Supplier rankings: {len(supplier_results)}")
print(f"Category-warehouse groups: {len(category_warehouse_results)}")
print(f"Top risk locations: {len(top_risk_locations)}")