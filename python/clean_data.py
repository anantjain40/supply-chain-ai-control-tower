"""Phase 2 — One consolidated cleaning and validation pass.

Only two SOURCE datasets are read: data/inventory.csv and data/suppliers.csv.
All files created under output/ are CLEANED extracts or audit logs.

Cleaning is intentionally evidence-based:
- Recover stable SKU attributes from other months/warehouses of the same SKU.
- Recover corrupted movement figures only using the inventory balance equation.
- Preserve unknown on-time delivery outcomes as NULL; exclude their delivery
  lines from on-time-rate denominators rather than inventing a success rate.
- Keep missing lead times for positive deliveries as NULL, and exclude only
  those delivery lines from observed-lead-time calculations.
- Mark missing supplier region as 'Unknown' (not guessed).
Any unexpected unreconciled constraint causes this program to stop.
"""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = ROOT / "output"
OUT.mkdir(parents=True, exist_ok=True)

SOURCE_INVENTORY = DATA / "inventory.csv"
SOURCE_SUPPLIERS = DATA / "suppliers.csv"

CATEGORIES = {
    "electronics": "Electronics", "fashion": "Fashion",
    "home & living": "Home & Living", "beauty": "Beauty", "sports": "Sports",
    "home appliances": "Home Appliances",
}
WAREHOUSES = {"north": "North", "south": "South", "west": "West"}
REGIONS = {"north": "North", "south": "South", "west": "West", "central": "Central"}
NUMERIC_COLUMNS = [
    "opening_stock_units", "received_units", "demand_units", "fulfilled_units",
    "closing_stock_units", "reorder_point_units", "unit_cost", "unit_selling_price",
    "stockout_days", "replenishment_lead_time_days", "supplier_deliveries_count",
    "supplier_on_time_deliveries_count",
]
INTEGERS = [
    "opening_stock_units", "received_units", "demand_units", "fulfilled_units",
    "closing_stock_units", "reorder_point_units", "stockout_days",
    "supplier_deliveries_count", "supplier_on_time_deliveries_count",
]
SUP_NUMERIC = ["contracted_lead_time_days", "contractual_on_time_target"]
changes: list[dict] = []


def blank_count(df: pd.DataFrame) -> dict[str, int]:
    return {str(col): int(n) for col, n in df.isna().sum().items() if int(n) > 0}


def tidy_text(x: object, *, style: str = "strip") -> str | None:
    if pd.isna(x):
        return None
    s = str(x).strip()
    if not s:
        return None
    if style == "upper":
        return s.upper()
    if style == "title":
        return s.title()
    return s


def edit(df: pd.DataFrame, idx: int, column: str, value: object, reason: str, source: str) -> None:
    old = df.at[idx, column]
    if (pd.isna(old) and pd.isna(value)) or (not pd.isna(old) and not pd.isna(value) and old == value):
        return
    key = "inventory_record_id" if source == "inventory" else "supplier_id"
    changes.append({
        "source": source, "record": str(df.at[idx, key]), "column": column,
        "before": "" if pd.isna(old) else str(old),
        "after": "" if pd.isna(value) else str(value), "reason": reason,
    })
    df.at[idx, column] = value


def normalize(df: pd.DataFrame, col: str, fn, reason: str, source: str) -> None:
    for idx, old in df[col].items():
        edit(df, idx, col, fn(old), reason, source)


def most_common_usable(series: pd.Series, test) -> object:
    values = [v for v in series.tolist() if pd.notna(v) and test(v)]
    if not values:
        raise ValueError(f"No defensible donor value for {series.name}")
    return Counter(values).most_common(1)[0][0]


def percent(numerator: float, denominator: float) -> float | None:
    return round(float(numerator) * 100 / float(denominator), 4) if denominator else None


def audit_and_clean() -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    inv = pd.read_csv(SOURCE_INVENTORY, dtype={"inventory_record_id": "string", "sku_id": "string", "supplier_id": "string"})
    sup = pd.read_csv(SOURCE_SUPPLIERS, dtype={"supplier_id": "string"})
    before = {
        "inventory_raw_rows": len(inv), "suppliers_raw_rows": len(sup),
        "inventory_missing_by_column": blank_count(inv),
        "suppliers_missing_by_column": blank_count(sup),
        "inventory_exact_duplicate_rows": int(inv.duplicated().sum()),
        "suppliers_exact_duplicate_rows": int(sup.duplicated().sum()),
    }
    if len(inv.columns) != 19 or len(sup.columns) != 7:
        raise ValueError("Source schema changed unexpectedly: expected inventory 19 / suppliers 7 columns")

    # 1) Drop exact duplicate source rows (not legitimate additional movements).
    inv = inv.drop_duplicates().reset_index(drop=True)
    sup = sup.drop_duplicates().reset_index(drop=True)

    # 2) Normalize keys and known finite label vocabularies.
    for col in ["inventory_record_id", "sku_id", "supplier_id"]:
        normalize(inv, col, lambda x: tidy_text(x, style="upper"), "normalize_key", "inventory")
    normalize(inv, "warehouse", lambda x: WAREHOUSES.get((tidy_text(x) or "").lower(), tidy_text(x)), "normalize_warehouse", "inventory")
    normalize(inv, "category", lambda x: CATEGORIES.get((tidy_text(x) or "").lower(), tidy_text(x)), "normalize_category", "inventory")
    normalize(inv, "product_name", tidy_text, "trim_product_name", "inventory")
    normalize(sup, "supplier_id", lambda x: tidy_text(x, style="upper"), "normalize_supplier_id", "suppliers")
    normalize(sup, "supplier_name", tidy_text, "trim_supplier_name", "suppliers")
    normalize(sup, "supplier_region", lambda x: REGIONS.get((tidy_text(x) or "").lower(), tidy_text(x)), "normalize_region", "suppliers")
    normalize(sup, "supplier_category", lambda x: CATEGORIES.get((tidy_text(x) or "").lower(), tidy_text(x)), "normalize_supplier_category", "suppliers")
    normalize(sup, "supplier_status", lambda x: (tidy_text(x) or "").title(), "normalize_supplier_status", "suppliers")

    # 3) Remove duplicate supplier IDs AFTER normalization; detect conflicting definitions.
    for supplier_id, group in sup.groupby("supplier_id", dropna=False):
        for col in sup.columns.drop("supplier_id"):
            real_vals = group[col].dropna().unique().tolist()
            if len(real_vals) > 1:
                raise ValueError(f"Conflicting supplier data: {supplier_id}, {col}: {real_vals}")
    duplicate_supplier_ids = int(sup.duplicated("supplier_id").sum())
    sup = sup.drop_duplicates("supplier_id").reset_index(drop=True)
    for idx in sup.index:
        if pd.isna(sup.at[idx, "supplier_region"]):
            edit(sup, idx, "supplier_region", "Unknown", "missing_region_explicit_unknown", "suppliers")

    # 4) Clean numeric typing and parse dates strictly.
    for col in NUMERIC_COLUMNS:
        inv[col] = pd.to_numeric(inv[col], errors="raise")
    for col in SUP_NUMERIC:
        sup[col] = pd.to_numeric(sup[col], errors="raise")
    inv["reporting_month"] = pd.to_datetime(inv["reporting_month"], errors="raise")
    if not (inv["reporting_month"].dt.day == 1).all():
        raise ValueError("Expected first-day-of-month reporting dates")
    if not inv["inventory_record_id"].is_unique:
        raise ValueError("Inventory record ID duplicates remain beyond exact duplicate rows")

    # 5) Recover SKU-stable reference fields using independent clean peer rows.
    for col in ["product_name", "category", "supplier_id", "unit_cost", "unit_selling_price"]:
        stable: dict[str, object] = {}
        for sku, group in inv.groupby("sku_id"):
            if col in ("unit_cost", "unit_selling_price"):
                stable[sku] = most_common_usable(group[col], lambda x: float(x) > 0)
            elif col == "supplier_id":
                active_sup_ids = set(sup["supplier_id"])
                stable[sku] = most_common_usable(group[col], lambda x: str(x) in active_sup_ids)
            else:
                stable[sku] = most_common_usable(group[col], lambda x: bool(str(x).strip()))
        for idx in inv.index:
            actual = inv.at[idx, col]
            canonical = stable[inv.at[idx, "sku_id"]]
            if pd.isna(actual) or actual != canonical:
                # Stable attribute values are invariant across the 36 records per SKU.
                edit(inv, idx, col, canonical, "restore_invariant_from_same_sku_peers", "inventory")

    # 6) Recover only financially/accountingly identifiable movement defects.
    # Receipts can be inferred from closing - opening + fulfilled if all peers are valid.
    for idx in inv.index:
        row = inv.loc[idx]
        if row["received_units"] < 0:
            calculated_receipts = row["closing_stock_units"] - row["opening_stock_units"] + row["fulfilled_units"]
            if calculated_receipts < 0:
                raise ValueError(f"Cannot recover negative receipts for {row['inventory_record_id']}")
            edit(inv, idx, "received_units", calculated_receipts, "recover_receipts_from_inventory_equation", "inventory")
    for idx in inv.index:
        row = inv.loc[idx]
        expected_close = row["opening_stock_units"] + row["received_units"] - row["fulfilled_units"]
        if expected_close < 0:
            raise ValueError(f"Cannot reconcile negative stock for {row['inventory_record_id']}")
        if row["closing_stock_units"] != expected_close:
            edit(inv, idx, "closing_stock_units", expected_close, "recalculate_closing_from_balanced_movements", "inventory")

    # 7) Some punctuality/lead-time facts cannot be recovered without a source.
    # Rather than invent, exclude unknown outcomes only from supplier service KPIs.
    for idx in inv.index:
        total = inv.at[idx, "supplier_deliveries_count"]
        ontime = inv.at[idx, "supplier_on_time_deliveries_count"]
        if pd.notna(ontime) and (ontime < 0 or ontime > total):
            edit(inv, idx, "supplier_on_time_deliveries_count", np.nan,
                 "unknown_on_time_count_excluded_from_service_rate", "inventory")
        measured = inv.at[idx, "replenishment_lead_time_days"]
        if total == 0 and pd.notna(measured):
            raise ValueError("Unexpected measured lead time for a zero-delivery row")
        if total > 0 and pd.notna(measured) and measured <= 0:
            edit(inv, idx, "replenishment_lead_time_days", np.nan,
                 "invalid_lead_time_excluded_from_lead_metric", "inventory")

    # 8) Strong reconciliation checks. Stop on unforeseen defects; do not silently guess.
    expected = inv["opening_stock_units"] + inv["received_units"] - inv["fulfilled_units"]
    checks = {
        "unique_inventory_record_ids": inv["inventory_record_id"].is_unique,
        "unique_sku_warehouse_month": not inv.duplicated(["sku_id", "warehouse", "reporting_month"]).any(),
        "unique_supplier_ids": sup["supplier_id"].is_unique,
        "valid_supplier_foreign_keys": inv["supplier_id"].isin(sup["supplier_id"]).all(),
        "recognized_warehouses": inv["warehouse"].isin(WAREHOUSES.values()).all(),
        "recognized_categories": inv["category"].isin(CATEGORIES.values()).all(),
        "valid_months": inv["reporting_month"].nunique() == 12,
        "all_nonnegative_inventory_counts": (inv[["opening_stock_units", "received_units", "demand_units", "fulfilled_units", "closing_stock_units", "reorder_point_units"]] >= 0).all().all(),
        "inventory_balances": expected.eq(inv["closing_stock_units"]).all(),
        "fulfilled_not_above_demand": (inv["fulfilled_units"] <= inv["demand_units"]).all(),
        "fulfilled_not_above_available": (inv["fulfilled_units"] <= inv["opening_stock_units"] + inv["received_units"]).all(),
        "valid_positive_prices": (inv["unit_cost"] > 0).all() and (inv["unit_selling_price"] > inv["unit_cost"]).all(),
        "nonnegative_delivery_counts": (inv["supplier_deliveries_count"] >= 0).all(),
        "valid_known_ontime_counts": (inv["supplier_on_time_deliveries_count"].dropna() >= 0).all()
            and (inv["supplier_on_time_deliveries_count"].fillna(-1) <= inv["supplier_deliveries_count"]).all(),
        "valid_supplier_contracts": (sup["contracted_lead_time_days"] > 0).all()
            and sup["contractual_on_time_target"].between(0, 1).all(),
        "full_4320_record_grid": len(inv) == 4320,
        "all_120_skus": inv["sku_id"].nunique() == 120,
        "all_3_warehouses": inv["warehouse"].nunique() == 3,
        "all_12_suppliers": len(sup) == 12,
        "stockout_days_in_month": inv["stockout_days"].between(0, inv["reporting_month"].dt.days_in_month).all(),
        "unmet_demand_stockout_consistency": ((inv["demand_units"] > inv["fulfilled_units"]) == (inv["stockout_days"] > 0)).all(),
        "all_integral_quantity_counts": all((inv[c].dropna() % 1 == 0).all() for c in INTEGERS),
    }
    ordered = inv.sort_values(["sku_id", "warehouse", "reporting_month"])
    prev = ordered.groupby(["sku_id", "warehouse"])["closing_stock_units"].shift(1)
    checks["month_to_month_stock_continuity"] = ordered.loc[prev.notna(), "opening_stock_units"].eq(prev[prev.notna()]).all()
    for name, ok in checks.items():
        if not bool(ok):
            raise AssertionError(f"FINAL VALIDATION FAILED: {name}")

    # Store observed missing fields without falsifying unknown source values.
    unknown_ontime_rows = int(inv["supplier_on_time_deliveries_count"].isna().sum())
    unknown_lead_rows = int(((inv["supplier_deliveries_count"] > 0)
                             & inv["replenishment_lead_time_days"].isna()).sum())

    # Preserve nullable integer counts as 0, 1, ... rather than 0.0000 for MySQL import.
    inv["supplier_on_time_deliveries_count"] = inv["supplier_on_time_deliveries_count"].astype("Int64")

    inv["days_in_month"] = inv["reporting_month"].dt.days_in_month.astype(int)
    inv["unfulfilled_units"] = inv["demand_units"] - inv["fulfilled_units"]
    inv["fulfilled_cogs_proxy"] = (inv["fulfilled_units"] * inv["unit_cost"]).round(2)
    inv["closing_inventory_value"] = (inv["closing_stock_units"] * inv["unit_cost"]).round(2)
    inv["potential_margin_exposure"] = (inv["unfulfilled_units"] * (inv["unit_selling_price"] - inv["unit_cost"])).round(2)
    inv["days_inventory_coverage"] = (inv["closing_stock_units"] / (inv["demand_units"] / inv["days_in_month"])).replace([np.inf, -np.inf], np.nan).round(4)
    inv["inventory_status"] = np.select(
        [inv["closing_stock_units"].eq(0),
         inv["closing_stock_units"].lt(inv["reorder_point_units"]),
         inv["closing_stock_units"].gt(2 * inv["reorder_point_units"])],
        ["Critical: Zero Stock", "At Risk: Below ROP", "Excess: >2x ROP"],
        default="Adequate",
    )
    inv["excess_stock_value_proxy"] = ((inv["closing_stock_units"] - 2 * inv["reorder_point_units"]).clip(lower=0) * inv["unit_cost"]).round(2)
    inv["reporting_month"] = inv["reporting_month"].dt.strftime("%Y-%m-%d")
    inv = inv.sort_values(["reporting_month", "sku_id", "warehouse"]).reset_index(drop=True)

    # Invariant across all rows for each SKU.
    for col in ["product_name", "category", "supplier_id", "unit_cost", "unit_selling_price"]:
        if inv.groupby("sku_id")[col].nunique(dropna=False).max() != 1:
            raise AssertionError(f"SKU reference attribute varies across rows: {col}")

    audit = {
        "source": "Synthetic data only; source CSVs are deliberately messy",
        "pre_clean_audit": before,
        "supplier_duplicate_ids_removed_after_standardization": duplicate_supplier_ids,
        "inventory_clean_rows": len(inv), "supplier_clean_rows": len(sup),
        "corrections_by_rule": dict(sorted(Counter(x["reason"] for x in changes).items())),
        "unresolved_supplier_service_measures": {
            "unknown_ontime_inventory_records": unknown_ontime_rows,
            "missing_observed_lead_time_with_deliveries": unknown_lead_rows,
            "policy": "Exclude unknown outcomes only from the affected KPI denominator; retain valid inventory records",
        },
        "final_validation": {k: bool(v) for k, v in checks.items()},
        "kpi_definitions": {
            "fill_rate": "SUM(fulfilled_units)/SUM(demand_units)",
            "stockout_occurrence": "COUNT(stockout_days>0)/COUNT(SKU-warehouse-month records)",
            "supplier_ontime_rate": "SUM(known on-time delivery lines)/SUM(delivery lines with known on-time counts)",
            "observed_lead_days": "SUM(lead days * delivery lines)/SUM(delivery lines with known lead days)",
            "closing_inventory_value": "SUM(closing_stock_units * unit_cost) for a single reporting month",
            "turnover_proxy": "SUM(fulfilled_units * unit_cost) over period / AVERAGE(monthly closing inventory value)",
            "potential_margin_exposure": "SUM(unfulfilled_units * (unit_selling_price - unit_cost)); scenario, not a realized loss",
        },
    }
    return inv, sup, audit



def main() -> None:
    """Clean the raw source files, save audit evidence, and STOP before SQL/KPI analysis."""
    inv, sup, audit = audit_and_clean()
    inv.to_csv(OUT / "inventory_clean.csv", index=False, float_format="%.4f")
    sup.to_csv(OUT / "suppliers_clean.csv", index=False)
    pd.DataFrame(changes).to_csv(OUT / "cleaning_changes.csv", index=False)
    with (OUT / "cleaning_audit.json").open("w", encoding="utf-8") as f:
        json.dump(audit, f, indent=2, allow_nan=False)

    print("\nPHASE 2 — CLEANING & VALIDATION COMPLETED")
    print(f"Raw inventory: {audit['pre_clean_audit']['inventory_raw_rows']:,} -> clean {len(inv):,} rows")
    print(f"Raw suppliers: {audit['pre_clean_audit']['suppliers_raw_rows']:,} -> clean {len(sup):,} rows")
    print(f"Duplicate inventory rows removed: {audit['pre_clean_audit']['inventory_exact_duplicate_rows']}")
    print(f"Duplicate supplier rows removed: {audit['pre_clean_audit']['suppliers_exact_duplicate_rows']}")
    print(f"All {len(audit['final_validation'])} integrity checks: PASSED")
    print(f"Documented field-level corrections: {len(changes):,}")
    unknown = audit['unresolved_supplier_service_measures']
    print(f"Unknown on-time outcomes retained as NULL: {unknown['unknown_ontime_inventory_records']}")
    print(f"Missing observed lead times WITH deliveries: {unknown['missing_observed_lead_time_with_deliveries']}")
    print("\nCORRECTIONS BY REASON:")
    for reason, count in audit['corrections_by_rule'].items():
        print(f"  {reason:<52} {count}")
    print("\nOUTPUT FILES (inside the existing project output/ folder):")
    for f in ["inventory_clean.csv", "suppliers_clean.csv", "cleaning_changes.csv", "cleaning_audit.json"]:
        print(f"  {f}")
    print("\nRaw source CSVs were not modified. No SQL or KPI analysis was executed.")


if __name__ == "__main__":
    main()
