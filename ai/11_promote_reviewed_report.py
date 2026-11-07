from pathlib import Path
from decimal import Decimal
from shutil import copy2
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output"

reviewed = OUTPUT / "supply_chain_executive_report_reviewed.md"
approved = OUTPUT / "gemini_investigation_approved.md"
status_file = OUTPUT / "gemini_validation_status.json"
brief_file = OUTPUT / "langgraph_investigation_brief.json"

# 1. Load the real validator and evidence.
module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

brief = json.loads(
    brief_file.read_text(encoding="utf-8")
)

report = reviewed.read_text(encoding="utf-8")

result = module["validate_ai_draft"]({
    "ai_analysis": report,
    "brief": brief
})

if not result["validated"]:
    raise SystemExit(
        f"APPROVAL BLOCKED: {result['validation_errors']}"
    )

# 2. Independently verify the corrected SKU exposure.
total = sum(
    Decimal(str(row["calculated_margin_exposure"]))
    for row in brief["ranked_priorities"]["top_risk_sku_locations"]
)

if (
    total != Decimal("1054853.80")
    or "₹10,54,853.80" not in report
):
    raise SystemExit("Financial reconciliation failed.")

# 3. Preserve the previous approved file and status.
archive = OUTPUT / "archive"
archive.mkdir(parents=True, exist_ok=True)

for file in (approved, status_file):
    backup = archive / (
        file.stem + "_before_editorial_approval" + file.suffix
    )
    if file.exists() and not backup.exists():
        copy2(file, backup)

previous_status = (
    json.loads(status_file.read_text(encoding="utf-8"))
    if status_file.exists()
    else {}
)

# 4. Remove the outdated pending-review banner.
if report.startswith("> **Editorially reviewed draft"):
    report = report.split("\n\n", 1)[1]

# 5. Promote the reviewed report.
approved.write_text(report, encoding="utf-8")

# 6. Record the approval method accurately.
status = {
    "validated": True,
    "validation_errors": [],
    "latest_report": str(approved),
    "approval_method": "Editorial review and offline revalidation",
    "source_report": str(reviewed),
    "gemini_api_called_for_promotion": False,
    "previous_live_attempts": previous_status.get("attempt_count"),
    "previous_live_validation_status": previous_status.get("validated"),
    "five_sku_margin_exposure": float(total),
    "review_scope": (
        "Structured KPI and risk claims, currency checks, "
        "five-SKU financial reconciliation, and editorial review"
    )
}

status_file.write_text(
    json.dumps(status, indent=2, ensure_ascii=False),
    encoding="utf-8"
)

print("\nFINAL REPORT PROMOTION: SUCCESS")
print("Approved report:", approved)
print("Validation status:", status_file)
print("Five-SKU margin exposure: ₹10,54,853.80")
print("Gemini API calls: 0")
print("Previous report/status backups:", archive)