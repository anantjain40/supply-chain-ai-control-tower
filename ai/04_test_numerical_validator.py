from pathlib import Path
import json
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]

# Load the existing validator without running Gemini.
module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

validate = module["validate_ai_draft"]

# Read the existing verified brief and AI draft.
brief = json.loads(
    (ROOT / "output" / "langgraph_investigation_brief.json")
    .read_text(encoding="utf-8")
)

draft = (
    ROOT / "output" / "gemini_investigation_draft.md"
).read_text(encoding="utf-8")

# Find the structured KPI JSON.
match = re.search(
    r"```json\s*(.*?)\s*```",
    draft,
    flags=re.IGNORECASE | re.DOTALL
)

if not match:
    raise ValueError("KPI JSON block not found.")

claims = json.loads(match.group(1))

# Deliberately introduce an incorrect Fill Rate.
claims["kpi_claims"]["fill_rate_pct"] = 94.50

modified_draft = (
    draft[:match.start(1)]
    + json.dumps(claims, indent=2)
    + draft[match.end(1):]
)

# Test the existing Node 6 validator.
result = validate({
    "ai_analysis": modified_draft,
    "brief": brief
})

assert result["validated"] is False
assert any(
    "fill_rate_pct: AI=" in error
    for error in result["validation_errors"]
)

print("\nNEGATIVE TEST PASSED")
print("The incorrect Fill Rate was successfully rejected.")