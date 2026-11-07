"""Generate exactly two intentionally messy, REPRODUCIBLE synthetic source CSVs.

Generated VALID business rows are coherent before a small, documented set of raw data
errors is injected for Phase 2. Do not use these raw files for unvalidated KPIs.
"""
from __future__ import annotations

from pathlib import Path
import calendar
import numpy as np
import pandas as pd

SEED = 20261102
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
DATA.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(SEED)

CATEGORIES = [
    "Electronics", "Fashion", "Home & Living", "Beauty", "Sports", "Home Appliances"
]
WAREHOUSES = ["North", "South", "West"]
REGIONS = ["North", "South", "West", "Central"]
COST_RANGES = {
    "Electronics": (900, 5200), "Fashion": (250, 1450),
    "Home & Living": (350, 2500), "Beauty": (120, 950),
    "Sports": (450, 3100), "Home Appliances": (1400, 6500),
}
MONTHS = pd.date_range("2025-11-01", periods=12, freq="MS")


def choose_distinct(count: int, forbidden: set[int], total: int) -> list[int]:
    """Pick different base-row positions so injected defects do not overlap."""
    candidates = np.array([i for i in range(total) if i not in forbidden], dtype=int)
    selected = rng.choice(candidates, size=count, replace=False).tolist()
    forbidden.update(selected)
    return selected


# One supplier per product family. Reliability varies organically by supplier.
supplier_records = []
supplier_reliability = {}
for i in range(12):
    supplier_id = f"SUP{i + 1:03d}"
    category = CATEGORIES[i // 2]
    contract_days = int(rng.integers(5, 15))
    reliability = float(rng.uniform(0.72, 0.975))
    target = float(rng.choice([0.90, 0.92, 0.95]))
    supplier_records.append({
        "supplier_id": supplier_id,
        "supplier_name": f"Nexa Vendor {i + 1:02d}",
        "supplier_region": REGIONS[i % len(REGIONS)],
        "supplier_category": category,
        "contracted_lead_time_days": contract_days,
        "contractual_on_time_target": target,
        "supplier_status": "Watchlist" if reliability < 0.79 else "Active",
    })
    supplier_reliability[supplier_id] = reliability
suppliers_truth = pd.DataFrame(supplier_records)
suppliers_lookup = suppliers_truth.set_index("supplier_id").to_dict("index")

# Each SKU has a stable product / category / supplier / price across all locations.
skus = []
for category_number, category in enumerate(CATEGORIES):
    low, high = COST_RANGES[category]
    for item_index in range(20):
        seq = category_number * 20 + item_index + 1
        assigned_supplier = f"SUP{category_number * 2 + (item_index % 2) + 1:03d}"
        cost = round(float(rng.uniform(low, high)), 2)
        price = round(cost * float(rng.uniform(1.20, 1.80)), 2)
        skus.append({
            "sku_id": f"SKU{seq:04d}",
            "product_name": f"{category} Product {item_index + 1:02d}",
            "category": category,
            "supplier_id": assigned_supplier,
            "unit_cost": cost,
            "unit_selling_price": price,
            "base_monthly_demand": float(rng.uniform(55, 195)),
        })

# Base rows: exactly one SKU x warehouse x month.
stock_state: dict[tuple[str, str], int] = {}
records = []
for month in MONTHS:
    month_str = month.strftime("%Y-%m-%d")
    days_in_month = calendar.monthrange(month.year, month.month)[1]
    # Mild peaks, not forced patterns of specific losses or "winner" suppliers.
    seasonal_factor = {11: 1.11, 12: 1.20, 1: 0.98, 2: 0.94, 6: 1.08,
                       7: 1.05, 9: 1.10, 10: 1.12}.get(month.month, 1.0)
    for sku in skus:
        sup = suppliers_lookup[sku["supplier_id"]]
        for warehouse, warehouse_scale in zip(WAREHOUSES, [1.06, 0.96, 1.0]):
            key = (sku["sku_id"], warehouse)
            base = sku["base_monthly_demand"] * warehouse_scale
            demand = max(1, int(round(base * seasonal_factor * rng.lognormal(0, 0.23))))
            opening = stock_state.get(key)
            if opening is None:
                opening = max(0, int(round(base * rng.uniform(0.55, 1.65))))
            contract = int(sup["contracted_lead_time_days"])
            # Simple reorder-policy proxy expressed in units.
            reorder_point = max(5, int(round((demand / days_in_month) * (contract + 5))))
            desired_receipt = max(0, demand + reorder_point - opening)
            reliability = supplier_reliability[sku["supplier_id"]]
            # Receipt variability and occasional non-delivery can produce real shortages.
            receipt_factor = float(rng.uniform(0.35, 1.35)) * (0.65 + 0.35 * reliability)
            received = max(0, int(round(desired_receipt * receipt_factor)))
            # Occasional bulk replenishment creates plausible *excess* inventory.
            # This is an operating decision, not a data-quality error.
            if rng.random() < 0.075:
                received += max(1, int(round(base * rng.uniform(1.5, 4.0))))
            if rng.random() < 0.065:
                received = 0
            if received > 0:
                deliveries_count = int(rng.integers(1, 5))
                on_time_count = int(rng.binomial(deliveries_count, reliability))
                late_fraction = (deliveries_count - on_time_count) / deliveries_count
                observed_lead = max(1, round(contract + 4.5 * late_fraction + rng.normal(0, 1.6)))
            else:
                deliveries_count = 0
                on_time_count = 0
                observed_lead = np.nan  # Legitimately not measured if no deliveries.

            available = opening + received
            fulfilled = min(demand, available)
            closing = available - fulfilled
            unfulfilled = demand - fulfilled
            stockout_days = (min(days_in_month, max(1, int(round(unfulfilled / max(demand / days_in_month, 1)))))
                             if unfulfilled > 0 else 0)
            stock_state[key] = closing
            records.append({
                "inventory_record_id": f"INV{len(records) + 1:06d}",
                "reporting_month": month_str,
                "sku_id": sku["sku_id"],
                "product_name": sku["product_name"],
                "category": sku["category"],
                "warehouse": warehouse,
                "supplier_id": sku["supplier_id"],
                "opening_stock_units": opening,
                "received_units": received,
                "demand_units": demand,
                "fulfilled_units": fulfilled,
                "closing_stock_units": closing,
                "reorder_point_units": reorder_point,
                "unit_cost": sku["unit_cost"],
                "unit_selling_price": sku["unit_selling_price"],
                "stockout_days": stockout_days,
                "replenishment_lead_time_days": observed_lead,
                "supplier_deliveries_count": deliveries_count,
                "supplier_on_time_deliveries_count": on_time_count,
            })

inventory_truth = pd.DataFrame(records)
assert len(inventory_truth) == 4320
assert inventory_truth[["sku_id", "warehouse", "reporting_month"]].duplicated().sum() == 0
assert ((inventory_truth.opening_stock_units + inventory_truth.received_units
         - inventory_truth.fulfilled_units) == inventory_truth.closing_stock_units).all()
assert (inventory_truth.fulfilled_units <= inventory_truth.demand_units).all()
assert (inventory_truth.fulfilled_units <= inventory_truth.opening_stock_units
        + inventory_truth.received_units).all()
assert (inventory_truth.supplier_on_time_deliveries_count
        <= inventory_truth.supplier_deliveries_count).all()
assert set(inventory_truth.supplier_id).issubset(set(suppliers_truth.supplier_id))
ordered = inventory_truth.sort_values(["sku_id", "warehouse", "reporting_month"])
prior_closing = ordered.groupby(["sku_id", "warehouse"]).closing_stock_units.shift(1)
assert (ordered.opening_stock_units[prior_closing.notna()].to_numpy()
        == prior_closing.dropna().to_numpy()).all()

# Inject a controlled, reproducible mixture of realistic RAW data defects.
raw = inventory_truth.copy()
used: set[int] = set()
issues: dict[str, int] = {}


def apply(n: int, issue: str, change):
    positions = choose_distinct(n, used, len(raw))
    for pos in positions:
        change(pos)
    issues[issue] = n


apply(45, "category_case_or_whitespace", lambda p: raw.at[p, "category"] and
      raw.at.__setitem__((p, "category"), " " + str(raw.at[p, "category"]).lower() + " "))
apply(36, "warehouse_case_or_whitespace", lambda p: raw.at.__setitem__(
    (p, "warehouse"), " " + str(raw.at[p, "warehouse"]).upper() + " "))
apply(32, "supplier_id_case_or_whitespace", lambda p: raw.at.__setitem__(
    (p, "supplier_id"), " " + str(raw.at[p, "supplier_id"]).lower() + " "))
apply(22, "missing_product_name", lambda p: raw.at.__setitem__((p, "product_name"), None))
apply(20, "missing_category", lambda p: raw.at.__setitem__((p, "category"), None))
apply(16, "missing_observed_lead_time", lambda p: raw.at.__setitem__(
    (p, "replenishment_lead_time_days"), np.nan))
apply(12, "missing_unit_cost", lambda p: raw.at.__setitem__((p, "unit_cost"), np.nan))
apply(6, "unknown_supplier_id", lambda p: raw.at.__setitem__((p, "supplier_id"), "SUP999"))
apply(7, "negative_received_units", lambda p: raw.at.__setitem__((p, "received_units"), -15))
apply(7, "negative_closing_stock", lambda p: raw.at.__setitem__((p, "closing_stock_units"), -20))
apply(6, "zero_unit_selling_price", lambda p: raw.at.__setitem__((p, "unit_selling_price"), 0.0))
apply(8, "incorrect_inventory_balance", lambda p: raw.at.__setitem__(
    (p, "closing_stock_units"), int(raw.at[p, "closing_stock_units"]) + 11))
apply(7, "on_time_count_exceeds_deliveries", lambda p: raw.at.__setitem__(
    (p, "supplier_on_time_deliveries_count"), int(raw.at[p, "supplier_deliveries_count"]) + 2))

# Duplicate *after* corruption so these rows are byte-identical to existing source rows.
duplicate_positions = rng.choice(len(raw), size=35, replace=False)
raw = pd.concat([raw, raw.iloc[duplicate_positions].copy()], ignore_index=True)
raw = raw.iloc[rng.permutation(len(raw))].reset_index(drop=True)

supplier_raw = suppliers_truth.copy()
supplier_raw.at[1, "supplier_region"] = " north "
supplier_raw.at[3, "supplier_region"] = "SOUTH"
supplier_raw.at[5, "supplier_region"] = None
supplier_raw.at[7, "supplier_status"] = " active "
supplier_raw.at[9, "supplier_name"] = " " + str(supplier_raw.at[9, "supplier_name"]) + " "
supplier_raw.at[10, "supplier_id"] = " " + str(supplier_raw.at[10, "supplier_id"]).lower() + " "
supplier_raw = pd.concat([supplier_raw, supplier_raw.iloc[[2, 8]].copy()], ignore_index=True)
supplier_raw = supplier_raw.iloc[rng.permutation(len(supplier_raw))].reset_index(drop=True)

raw.to_csv(DATA / "inventory.csv", index=False, float_format="%.2f")
supplier_raw.to_csv(DATA / "suppliers.csv", index=False)

print("Synthetic RAW datasets regenerated successfully (fixed seed).")
print(f"inventory.csv: {len(raw):,} rows | {raw.shape[1]} columns")
print(f"suppliers.csv: {len(supplier_raw):,} rows | {supplier_raw.shape[1]} columns")
print("VALID underlying data: 4,320 SKU–warehouse–month rows and 12 suppliers")
print("Injected inventory defects:")
for issue, count in issues.items():
    print(f"  - {issue}: {count}")
print("  - exact_duplicate_rows_added: 35")
print("Injected supplier issues: 2 duplicate rows; missing/case/whitespace variants")
print("NOTE: Zero-delivery rows legitimately have no observed lead time.")
print("Do not draw business conclusions until Phase 2 cleaning and validation.")
