from pathlib import Path
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]

# Load our existing validator.
module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

validate = module["validate_ai_draft"]

# Load verified investigation evidence.
brief = json.loads(
    (
        ROOT / "output"
        / "langgraph_investigation_brief.json"
    ).read_text(encoding="utf-8")
)

# Load the reviewed executive report.
report = (
    ROOT / "output"
    / "supply_chain_executive_report_reviewed.md"
).read_text(encoding="utf-8")

# Validate the existing structured claims.
result = validate({
    "ai_analysis": report,
    "brief": brief
})

print("\nFINAL STRUCTURED VALIDATION:")
print("Status:", "PASS" if result["validated"] else "FAIL")
print("Issues:", result["validation_errors"])

if not result["validated"]:
    raise SystemExit(
        "Reviewed report failed validation."
    )

# Independently verify the corrected SKU total.
sku_records = brief[
    "ranked_priorities"
]["top_risk_sku_locations"]

total_exposure = round(
    sum(
        item["calculated_margin_exposure"]
        for item in sku_records
    ),
    2
)

assert total_exposure == 1054853.80

# Confirm that the report includes the correct total.
assert "₹10,54,853.80" in report

print("Five-SKU exposure:", total_exposure)
print("Financial total: VERIFIED")

print("\nREVIEWED EXECUTIVE REPORT: VALIDATION PASSED")