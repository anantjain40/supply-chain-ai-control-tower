from pathlib import Path
import runpy

# ==========================================
# 1. LOAD EXISTING ROUTER
# ==========================================

ROOT = Path(__file__).resolve().parents[1]

module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

router = module["route_after_validation"]


# ==========================================
# TEST 1 — VALID REPORT
# ==========================================

state_1 = {
    "validated": True,
    "attempt_count": 1,
    "validation_errors": []
}

result_1 = router(state_1)

assert result_1 == "approved"

print("TEST 1 PASSED: Valid report approved")


# ==========================================
# TEST 2 — FIRST ATTEMPT FAILED
# ==========================================

state_2 = {
    "validated": False,
    "attempt_count": 1,
    "validation_errors": [
        "Incorrect supplier delivery rate"
    ]
}

result_2 = router(state_2)

assert result_2 == "retry"

print("TEST 2 PASSED: First failure triggers retry")


# ==========================================
# TEST 3 — SECOND ATTEMPT FAILED
# ==========================================

state_3 = {
    "validated": False,
    "attempt_count": 2,
    "validation_errors": [
        "Incorrect SKU financial exposure"
    ]
}

result_3 = router(state_3)

assert result_3 == "rejected"

print("TEST 3 PASSED: Second failure rejected")


print("\nCONDITIONAL ROUTING: 3/3 TESTS PASSED")