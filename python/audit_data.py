"""Phase 2 / Checkpoint 1: READ-ONLY audit of two raw source CSVs."""
from pathlib import Path
import pandas as pd

root = Path(__file__).resolve().parents[1]
inventory_raw = pd.read_csv(root / "data" / "inventory.csv")
suppliers_raw = pd.read_csv(root / "data" / "suppliers.csv")

# Use a temporary deduplicated view so copied rows do not inflate defect counts.
# Original CSV files remain untouched; no cleaned files are written here.
inv = inventory_raw.drop_duplicates().copy()
sup = suppliers_raw.drop_duplicates().copy()


def total(condition):
    """Count how many rows satisfy a validation rule."""
    return int(condition.fillna(False).sum())


def report(label, number):
    print(f"  {label:<43} {number}")


print("\n[A] FILE STRUCTURE & DUPLICATES")
report("Raw inventory rows", len(inventory_raw))
report("Raw supplier rows", len(suppliers_raw))
report("Exact inventory duplicate rows", total(inventory_raw.duplicated()))
report("Exact supplier duplicate rows", total(suppliers_raw.duplicated()))

# Normalize keys only in memory, for fair comparison.
warehouse = inv["warehouse"].astype("string").str.strip().str.title()
supplier_id = inv["supplier_id"].astype("string").str.strip().str.upper()
sup_id = sup["supplier_id"].astype("string").str.strip().str.upper()
category = inv["category"].astype("string").str.strip().str.title()
report("Duplicate SKU + warehouse + month keys",
       total(inv.assign(warehouse_normalized=warehouse).duplicated(
           ["sku_id", "warehouse_normalized", "reporting_month"])))
report("Duplicate normalized supplier IDs", total(sup_id.duplicated()))

print("\n[B] MISSING VALUES (unique raw rows)")
for col, n in inv.isna().sum().items():
    if n:
        report("inventory." + col, int(n))
for col, n in sup.isna().sum().items():
    if n:
        report("suppliers." + col, int(n))
report("Missing lead time WITH deliveries",
       total(inv["replenishment_lead_time_days"].isna()
             & (inv["supplier_deliveries_count"] > 0)))
report("Missing lead time with ZERO deliveries (valid)",
       total(inv["replenishment_lead_time_days"].isna()
             & (inv["supplier_deliveries_count"] == 0)))

print("\n[C] LABEL FORMATTING")
report("Category case/space variations",
       total(inv["category"].notna() & (inv["category"] != category)))
report("Warehouse case/space variations",
       total(inv["warehouse"].notna() & (inv["warehouse"] != warehouse)))
report("Inventory supplier-ID case/space variations",
       total(inv["supplier_id"].notna() & (inv["supplier_id"] != supplier_id)))
report("Supplier-ID case/space variations",
       total(sup["supplier_id"].notna() & (sup["supplier_id"] != sup_id)))

print("\n[D] NUMERIC & BUSINESS-RULE CHECKS")
report("Negative received units", total(inv["received_units"] < 0))
report("Negative closing stock", total(inv["closing_stock_units"] < 0))
report("Nonpositive or missing unit cost", total(inv["unit_cost"].isna() | (inv["unit_cost"] <= 0)))
report("Nonpositive selling price", total(inv["unit_selling_price"] <= 0))
report("Fulfilled units above demand", total(inv["fulfilled_units"] > inv["demand_units"]))
report("Fulfilled units above available stock",
       total(inv["fulfilled_units"] > inv["opening_stock_units"] + inv["received_units"]))
report("On-time delivery count exceeds total",
       total(inv["supplier_on_time_deliveries_count"] > inv["supplier_deliveries_count"]))
report("Negative delivery counts", total((inv["supplier_deliveries_count"] < 0)
                                         | (inv["supplier_on_time_deliveries_count"] < 0)))
report("Nonpositive observed lead time WITH deliveries",
       total((inv["supplier_deliveries_count"] > 0)
             & (inv["replenishment_lead_time_days"] <= 0)))
report("Inventory balance mismatches",
       total((inv["opening_stock_units"] + inv["received_units"]
              - inv["fulfilled_units"]) != inv["closing_stock_units"]))

print("\n[E] REFERENCES & DATE CHECKS")
report("Supplier IDs absent from suppliers.csv",
       total(supplier_id.notna() & ~supplier_id.isin(sup_id.dropna())))
report("Unexpected warehouse labels",
       total(warehouse.notna() & ~warehouse.isin(["North", "South", "West"])))
report("Unexpected category labels",
       total(category.notna() & ~category.isin([
           "Electronics", "Fashion", "Home & Living", "Beauty", "Sports", "Home Appliances"])))
report("Unparseable reporting dates",
       total(pd.to_datetime(inv["reporting_month"], errors="coerce").isna()))
report("Invalid supplier contract lead times", total(sup["contracted_lead_time_days"] <= 0))
report("Invalid supplier target percentages",
       total(~sup["contractual_on_time_target"].between(0, 1)))
print("\nAudit finished: NO raw data was modified.\n")
