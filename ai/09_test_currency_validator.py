from pathlib import Path
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]

# Load our actual validator without executing Gemini.
module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

validate = module["validate_ai_draft"]

# Read verified evidence.
brief = json.loads(
    (
        ROOT / "output"
        / "langgraph_investigation_brief.json"
    ).read_text(encoding="utf-8")
)

# Read the report rejected due to LaTeX formatting.
report = (
    ROOT / "output"
    / "gemini_investigation_rejected.md"
).read_text(encoding="utf-8")


def check(text):
    return validate({
        "ai_analysis": text,
        "brief": brief
    })


# TEST 1: Existing report should now pass.
result = check(report)

assert result["validated"] is True, (
    result["validation_errors"]
)

print("TEST 1 PASSED: LaTeX calculations accepted")


# TEST 2: Genuine dollar amount must be rejected.
modified = report + "\n\nExample cost: $500."

result = check(modified)

assert result["validated"] is False
assert any(
    "Incorrect currency" in error
    for error in result["validation_errors"]
)

print("TEST 2 PASSED: Dollar amount rejected")


# TEST 3: Explicit USD must be rejected.
modified = report + "\n\nExample cost: USD 500."

result = check(modified)

assert result["validated"] is False
assert any(
    "Incorrect currency" in error
    for error in result["validation_errors"]
)

print("TEST 3 PASSED: USD reference rejected")


print("\nCURRENCY REGRESSION TESTS: 3/3 PASSED")