from pathlib import Path
from unittest.mock import patch
from contextlib import redirect_stdout
from langgraph.graph.state import CompiledStateGraph

import io
import json
import runpy


ROOT = Path(__file__).resolve().parents[1]

SOURCE = ROOT / "ai" / "02_langgraph_workflow.py"


# Simulated results only — not real project metrics.
def simulate_report(validated):

    captured_files = {}
    terminal_output = io.StringIO()

    # Capture report writes in memory.
    # No actual report files will be overwritten.
    def fake_write_text(path, content, encoding=None):
        captured_files[path.name] = content
        return len(content)

    fake_result = {
        "validated": validated,
        "attempt_count": 1 if validated else 2,
        "validation_errors": (
            [] if validated else ["Simulated KPI mismatch"]
        ),
        "ai_analysis": "SIMULATED REPORT — TEST ONLY",
        "priorities": {
            "top_three_exposure_share_pct": 49.61,
            "top_category_warehouse_workstreams": [{}] * 5,
            "lowest_on_time_suppliers": [{}] * 3,
            "top_risk_sku_locations": [{}] * 5,
        },
    }

    exit_code = 0

    with (
        patch.object(
            CompiledStateGraph,
            "invoke",
            return_value=fake_result
        ),
        patch.object(
            Path,
            "write_text",
            new=fake_write_text
        ),
        redirect_stdout(terminal_output)
    ):
        try:
            runpy.run_path(
                str(SOURCE),
                run_name="__main__"
            )
        except SystemExit as error:
            exit_code = error.code

    return captured_files, exit_code, terminal_output.getvalue()


# ==========================================
# TEST 1 — APPROVED REPORT
# ==========================================

files, exit_code, log = simulate_report(True)

status = json.loads(
    files["gemini_validation_status.json"]
)

assert exit_code == 0
assert status["validated"] is True
assert "gemini_investigation_approved.md" in files
assert "gemini_investigation_rejected.md" not in files
assert "LANGGRAPH WORKFLOW: SUCCESS" in log

print("TEST 1 PASSED: Approved report handled correctly")


# ==========================================
# TEST 2 — REJECTED REPORT
# ==========================================

files, exit_code, log = simulate_report(False)

status = json.loads(
    files["gemini_validation_status.json"]
)

assert exit_code == 1
assert status["validated"] is False
assert "gemini_investigation_rejected.md" in files
assert "gemini_investigation_approved.md" not in files
assert "LANGGRAPH WORKFLOW: REJECTED" in log
assert "LANGGRAPH WORKFLOW: SUCCESS" not in log

print("TEST 2 PASSED: Rejected report blocked correctly")


print("\nFINAL REPORT SAFEGUARDS: 2/2 TESTS PASSED")