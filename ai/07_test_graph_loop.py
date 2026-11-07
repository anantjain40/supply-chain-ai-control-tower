from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import json
import re
import runpy

# ==========================================
# 1. LOAD OUR ACTUAL COMPILED LANGGRAPH
# ==========================================

ROOT = Path(__file__).resolve().parents[1]

module = runpy.run_path(
    str(ROOT / "ai" / "02_langgraph_workflow.py")
)

graph = module["graph"]

# Read the previously validated AI draft.
valid_report = (
    ROOT / "output" / "gemini_investigation_draft.md"
).read_text(encoding="utf-8")


# ==========================================
# 2. CREATE AN INCORRECT AI RESPONSE
# ==========================================

def create_invalid_report(report):

    match = re.search(
        r"```json\s*(.*?)\s*```",
        report,
        flags=re.IGNORECASE | re.DOTALL
    )

    if not match:
        raise ValueError("Structured KPI JSON missing.")

    claims = json.loads(match.group(1))

    # Deliberately change the verified Fill Rate.
    claims["kpi_claims"]["fill_rate_pct"] = 94.50

    return (
        report[:match.start(1)]
        + json.dumps(claims, indent=2)
        + report[match.end(1):]
    )


invalid_report = create_invalid_report(valid_report)


# ==========================================
# 3. SIMULATE GEMINI WITHOUT API REQUESTS
# ==========================================

def test_scenario(name, responses, expected_valid):

    calls = 0

    def fake_generate_content(*, model, contents):

        nonlocal calls

        if calls >= len(responses):
            raise AssertionError(
                "Unexpected additional Gemini attempt."
            )

        response_text = responses[calls]
        calls += 1

        return SimpleNamespace(text=response_text)

    fake_client = SimpleNamespace(
        models=SimpleNamespace(
            generate_content=fake_generate_content
        )
    )

    # Replace only Gemini's API client during the test.
    with patch(
        "google.genai.Client",
        return_value=fake_client
    ):
        result = graph.invoke({})

    assert result["validated"] is expected_valid

    assert result["attempt_count"] == len(responses)

    assert calls == len(responses)

    print(f"\n{name}: PASSED")
    print("Gemini attempts:", calls)
    print("Validated:", result["validated"])


# ==========================================
# TEST 1 — CORRECT REPORT APPROVED
# ==========================================

test_scenario(
    "TEST 1: Immediate approval",
    [valid_report],
    True
)


# ==========================================
# TEST 2 — ERROR CORRECTED ON RETRY
# ==========================================

test_scenario(
    "TEST 2: Successful correction",
    [invalid_report, valid_report],
    True
)


# ==========================================
# TEST 3 — BOTH ATTEMPTS FAIL
# ==========================================

test_scenario(
    "TEST 3: Rejection after two attempts",
    [invalid_report, invalid_report],
    False
)


print("\nFULL LANGGRAPH LOOP: 3/3 TESTS PASSED")