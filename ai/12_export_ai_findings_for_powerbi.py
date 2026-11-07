"""Export approved LangGraph/Gemini investigation findings for Power BI.

Source: output/gemini_investigation_approved.md
Destination: output/ai_findings_powerbi.csv

The CSV contains the report's five risk narratives and prescribed actions.
It is a fixed October 2026 snapshot, not a live interactive AI service.
"""

from pathlib import Path
import csv
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output"
REPORT_PATH = OUTPUT / "gemini_investigation_approved.md"
STATUS_PATH = OUTPUT / "gemini_validation_status.json"
CSV_PATH = OUTPUT / "ai_findings_powerbi.csv"

if not REPORT_PATH.is_file():
    raise SystemExit("Approved report not found in output/.")
if not STATUS_PATH.is_file():
    raise SystemExit("Validation status not found in output/.")

status = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
if status.get("validated") is not True:
    raise SystemExit("Approval status is not validated=True; export blocked.")

report = REPORT_PATH.read_text(encoding="utf-8-sig")
if report.lstrip().startswith("# REJECTED AI REPORT"):
    raise SystemExit("This is a rejected report; export blocked.")

section_match = re.search(
    r"(?ms)^## Top Five Supply Chain Problems\s*\n(.*?)(?=^## |\Z)",
    report,
)
if not section_match:
    raise SystemExit("Could not find 'Top Five Supply Chain Problems' section.")

blocks = re.findall(
    r"(?ms)^###\s+(\d+)\.\s+([^\n]+)\n(.*?)(?=^###\s+\d+\.|^## |\Z)",
    section_match.group(1),
)

def clean_markdown(value: str) -> str:
    value = re.sub(r"\*\*(.+?)\*\*", r"\1", value)
    value = value.replace("`", "")
    return " ".join(value.split())


def get_field(body: str, label: str) -> str:
    match = re.search(
        rf"(?m)^\*\s+\*\*{re.escape(label)}:\*\*\s*(.+)$",
        body,
    )
    return clean_markdown(match.group(1)) if match else ""


fields = {
    "evidence": "Numerical Evidence",
    "hypothesis_unproven": "Root-Cause Hypotheses (Unproven)",
    "recommended_action": "Recommended Action",
    "owner": "Responsible Owner",
    "timeframe": "Timeframe",
    "illustrative_target": "Illustrative Target",
    "verification_method": "Verification Method",
}

rows = []
for rank, heading, body in blocks:
    record = {
        "priority": int(rank),
        "finding": clean_markdown(heading),
        "reporting_month": "2026-10",
        "approval_method": status.get("approval_method", "Validated report"),
    }
    record.update({key: get_field(body, label) for key, label in fields.items()})
    missing = [key for key in fields if not record[key]]
    if missing:
        raise SystemExit(f"Finding {rank}: missing report fields {missing}")
    rows.append(record)

if [row["priority"] for row in rows] != [1, 2, 3, 4, 5]:
    raise SystemExit("Expected exactly five numbered report findings.")

columns = ["priority", "finding", "reporting_month", "evidence",
           "hypothesis_unproven", "recommended_action", "owner",
           "timeframe", "illustrative_target", "verification_method",
           "approval_method"]
with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=columns)
    writer.writeheader()
    writer.writerows(rows)

print("AI FINDINGS EXPORT: SUCCESS")
print("Source:", REPORT_PATH)
print("CSV:", CSV_PATH)
print("Rows:", len(rows))
print("Report status: validated; editorially reviewed")
print("AI API calls: 0")
for row in rows:
    print(f"  {row['priority']}. {row['finding']}")
