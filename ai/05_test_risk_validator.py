from pathlib import Path
from copy import deepcopy
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]

# Load our existing detailed risk validator.
module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

validate = module["check_risk_claims"]

# Load the verified investigation brief.
brief = json.loads(
    (
        ROOT / "output"
        / "langgraph_investigation_brief.json"
    ).read_text(encoding="utf-8")
)

priorities = brief["ranked_priorities"]


# Build valid claims from source evidence.
def select_fields(rows, fields):
    return [
        {field: row[field] for field in fields}
        for row in rows
    ]


valid_claims = {
    "workstreams": select_fields(
        priorities["top_category_warehouse_workstreams"][:3],
        (
            "category",
            "warehouse",
            "fill_rate_pct",
            "potential_gross_margin_exposure",
        )
    ),
    "suppliers": select_fields(
        priorities["lowest_on_time_suppliers"][:3],
        (
            "supplier_id",
            "on_time_rate_pct",
            "eligible_deliveries",
        )
    ),
    "sku_locations": select_fields(
        priorities["top_risk_sku_locations"][:5],
        (
            "sku_id",
            "warehouse",
            "unfulfilled_units",
            "calculated_margin_exposure",
        )
    ),
}


# TEST 1 — Valid evidence should pass.
errors = validate(valid_claims, priorities)
assert errors == [], errors

print("TEST 1 PASSED: Correct risk evidence accepted")


# TEST 2 — Incorrect supplier percentage.
supplier_test = deepcopy(valid_claims)

supplier_test["suppliers"][0]["on_time_rate_pct"] = 95.0

errors = validate(supplier_test, priorities)

assert any(
    "on_time_rate_pct" in error
    for error in errors
), errors

print("TEST 2 PASSED: Wrong supplier rate rejected")


# TEST 3 — Incorrect SKU financial exposure.
sku_test = deepcopy(valid_claims)

sku_test["sku_locations"][0][
    "calculated_margin_exposure"
] = 800000.0

errors = validate(sku_test, priorities)

assert any(
    "calculated_margin_exposure" in error
    for error in errors
), errors

print("TEST 3 PASSED: Wrong SKU exposure rejected")


# TEST 4 — Invented SKU identifier.
identifier_test = deepcopy(valid_claims)

identifier_test["sku_locations"][0]["sku_id"] = "SKU9999"

errors = validate(identifier_test, priorities)

assert any(
    "Unknown" in error
    for error in errors
), errors

print("TEST 4 PASSED: Invented SKU rejected")


print("\nDETAILED RISK VALIDATION: 4/4 TESTS PASSED")