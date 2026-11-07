from pathlib import Path
from typing import TypedDict, Any
import json

import re
import math
import os
from dotenv import load_dotenv
from google import genai
from langgraph.graph import StateGraph, START, END


# ==========================================
# 1. PROJECT FILE PATHS
# ==========================================

ROOT = Path(__file__).resolve().parents[1]

EVIDENCE_FILE = (
    ROOT / "output" / "ai_evidence_oct2026.json"
)

OUTPUT_FILE = (
    ROOT / "output" / "langgraph_investigation_brief.json"
)


# ==========================================
# 2. SHARED LANGGRAPH STATE
# ==========================================

class InvestigationState(TypedDict, total=False):
    evidence: dict[str, Any]
    verified: bool
    priorities: dict[str, Any]
    brief: dict[str, Any]
    ai_analysis: str
    validated: bool
    validation_errors: list[str]
    attempt_count: int

# ==========================================
# NODE 1 — LOAD BUSINESS EVIDENCE
# ==========================================

def load_evidence(state: InvestigationState):

    print("NODE 1: Loading verified evidence")

    with open(EVIDENCE_FILE, "r", encoding="utf-8") as f:
        evidence = json.load(f)

    return {"evidence": evidence}


# ==========================================
# NODE 2 — VALIDATE EVIDENCE
# ==========================================

def validate_evidence(state: InvestigationState):

    print("NODE 2: Validating evidence")

    evidence = state["evidence"]

    checks = evidence["sql_benchmark_verification"]

    failed = [
        name
        for name, result in checks.items()
        if not result["passed"]
    ]

    if len(checks) != 10 or failed:
        raise ValueError(
            f"Evidence QA failed: {failed}"
        )

    if evidence["reporting_month"] != "2026-10":
        raise ValueError("Unexpected reporting month")

    if len(evidence["category_warehouse_priorities"]) != 18:
        raise ValueError("Expected 18 category-warehouse groups")

    print("Evidence QA: 10/10 PASSED")

    return {"verified": True}


# ==========================================
# NODE 3 — PRIORITIZE SUPPLY CHAIN RISKS
# ==========================================

def prioritize_risks(state: InvestigationState):

    print("NODE 3: Ranking operational risks")

    if not state.get("verified"):
        raise ValueError("Evidence must be verified first")

    evidence = state["evidence"]

    workstreams = evidence["category_warehouse_priorities"]

    top_workstreams = workstreams[:5]

    total_exposure = evidence["october_kpis"][
        "potential_gross_margin_exposure"
    ]

    top_three_exposure = sum(
        item["potential_gross_margin_exposure"]
        for item in top_workstreams[:3]
    )

    top_three_share = (
        100 * top_three_exposure / total_exposure
        if total_exposure > 0 else 0
    )

    # Exclude suppliers without eligible deliveries.
    suppliers = [
        item
        for item in evidence["supplier_performance"]
        if item["eligible_deliveries"] > 0
    ]

    suppliers.sort(
        key=lambda item: item["on_time_rate_pct"]
    )

    priorities = {
        "top_category_warehouse_workstreams":
            top_workstreams,

        "top_three_exposure_share_pct":
            round(top_three_share, 2),

        "lowest_on_time_suppliers":
            suppliers[:3],

        "top_risk_sku_locations":
            evidence["top_risk_sku_locations"][:5],
    }

    return {"priorities": priorities}


# ==========================================
# NODE 4 — PREPARE INVESTIGATION BRIEF
# ==========================================

def build_investigation_brief(state: InvestigationState):

    print("NODE 4: Preparing investigation brief")

    evidence = state["evidence"]

    brief = {
        "project": evidence["project"],

        "reporting_month":
            evidence["reporting_month"],
        "currency": evidence["currency"],

        "currency_symbol": evidence["currency_symbol"],

        "business_rules": evidence["business_rules"],
        "source_evidence":
            "output/ai_evidence_oct2026.json",

        "sql_checks_passed": 10,

        "october_kpis":
            evidence["october_kpis"],

        "ranked_priorities":
            state["priorities"],

        "limitations":
            evidence["limitations"],

        "interpretation_rules": [
            "Do not invent financial amounts.",
            "Potential margin exposure is not realized loss.",
            "Supplier association does not prove causation.",
            "Proposed root causes must be labeled hypotheses.",
            "Every recommendation must reference evidence.",
        ],
    }

    OUTPUT_FILE.parent.mkdir(
        parents=True, exist_ok=True
    )

    with open(
        OUTPUT_FILE, "w", encoding="utf-8"
    ) as f:
        json.dump(brief, f, indent=2, ensure_ascii=False)

    return {"brief": brief}

# ==========================================
# NODE 5 — GEMINI AI INVESTIGATION
# ==========================================

def generate_ai_insights(state: InvestigationState):

    print("NODE 5: Generating Gemini AI insights")

    # Load Gemini API key securely.
    load_dotenv(ROOT / ".env")

    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        raise ValueError("Gemini API key not found")

    client = genai.Client(api_key=api_key)

    # Use our verified investigation brief.
    brief = state["brief"]
    attempt = state.get("attempt_count", 0) + 1

    if attempt > 2:
        raise ValueError(
            "Maximum Gemini attempts exceeded."
        )

    print(f"Gemini generation attempt: {attempt}/2")

    prompt = f"""
    You are a Senior Supply Chain Business Analyst.

    Analyze the following verified business evidence
    from a synthetic supply-chain dataset.

    EVIDENCE:
    {json.dumps(brief, indent=2)}

    TASKS:

    1. Identify the five most important
       supply-chain problems.

    2. Explain the numerical evidence supporting
       each problem.

    3. Identify possible root causes.
       Clearly label them as hypotheses,
       not proven facts.

    4. Recommend practical business actions
       with priorities and suggested owners.

    5. Explain potential financial impact,
       using only the provided figures.

        RULES:

    CURRENCY AND FINANCIAL ACCURACY:
    - All monetary amounts are in Indian Rupees (INR).
    - Always use ₹, never $ or USD.
    - Never convert currencies.
    - Never invent KPI values or financial figures.
    - Check arithmetic before reporting totals.
    - Financial exposure is potential, not realized loss.

    BUSINESS RULES:
    - Stockouts are defined as stockout_days > 0.
    - Zero closing stock is a separate inventory condition.
    - Use the business definitions in the evidence.
    - Never claim hypotheses are proven root causes.
    - Supplier association does not establish causation.

    RECOMMENDATION QUALITY:
    - Rank business issues by severity and financial exposure.
    - Support every finding with specific numerical evidence.
    - Reference relevant SKU IDs, suppliers and warehouses.
    - Recommend practical actions for each major issue.
    - Specify the proposed owner and implementation timeframe.
    - Define measurable success KPIs.
    - Label proposed targets as illustrative assumptions.
    - Clearly distinguish facts from hypotheses.
    - State when information is insufficient.
    - Do not invent monthly comparisons or other missing data.

    REPORT QUALITY:
    - Produce five detailed, evidence-backed investigations.
    - Include a quantified executive summary.
    - Include financial implications and operational risks.
    - Conclude with a prioritized management action plan.
    - State that the underlying dataset is synthetic.
    - Write in professional business-report language.
            MACHINE-READABLE EVIDENCE VALIDATION:

    At the very end of the executive report,
    include exactly one fenced code block
    labeled json.

    The JSON object must contain exactly
    two properties:
    "kpi_claims" and "risk_claims".

    SECTION 1 — KPI CLAIMS:

    "kpi_claims" must contain exactly
    these ten numeric fields:

    fill_rate_pct
    stockout_rate_pct
    at_risk_rate_pct
    supplier_on_time_rate_pct
    weighted_lead_time_days
    closing_inventory_value
    inventory_coverage_days
    inventory_turnover
    potential_unmet_sales
    potential_gross_margin_exposure

    Copy all values directly from october_kpis.

    SECTION 2 — RISK CLAIMS:

    "risk_claims" must contain exactly
    three arrays:

    "workstreams"
    "suppliers"
    "sku_locations"

    WORKSTREAMS:
    Include the top 3 entries from
    ranked_priorities.top_category_warehouse_workstreams.

    For each entry include:
    category
    warehouse
    fill_rate_pct
    potential_gross_margin_exposure

    SUPPLIERS:
    Include all 3 entries from
    ranked_priorities.lowest_on_time_suppliers.

    For each entry include:
    supplier_id
    on_time_rate_pct
    eligible_deliveries

    SKU LOCATIONS:
    Include all 5 entries from
    ranked_priorities.top_risk_sku_locations.

    For each entry include:
    sku_id
    warehouse
    unfulfilled_units
    calculated_margin_exposure

    GENERAL JSON RULES:
    - Use valid JSON syntax.
    - All numeric fields must be JSON numbers.
    - Never include ₹, %, or commas in numeric values.
    - Copy every figure directly from the evidence.
    - Never invent identifiers or amounts.
    - Do not add extra JSON properties.
    - Keep the human-readable report above
      this JSON block.
    """
        # ==========================================
    # FINAL BUSINESS NARRATIVE AUDIT RULES
    # ==========================================

    previous_month = max(
        (
            row
            for row in state["evidence"]["monthly_trends"]
            if row["month"] < brief["reporting_month"]
        ),
        key=lambda row: row["month"],
        default=None
    )

    supplier_details = state["evidence"][
        "supplier_performance"
    ]

    prompt += """

    FINAL EXECUTIVE REPORT QUALITY REQUIREMENTS:

    1. EVIDENCE VS HYPOTHESES

    Separate:
    - Verified business findings
    - Possible root-cause hypotheses
    - Recommended investigations

    Do not claim that forecasting failures,
    supplier manufacturing delays, logistics
    bottlenecks, reorder-system failures or
    inadequate safety stock are proven causes.

    Explain what additional business evidence
    would be required to confirm each hypothesis.

    2. SUPPLIER PRIORITIZATION

    Evaluate supplier performance using BOTH:
    - On-time delivery rate
    - Associated potential gross margin exposure

    Explicitly compare suppliers with poor
    delivery reliability against those with
    high associated financial exposure.

    Supplier association does not establish
    that the supplier caused unfulfilled demand.

    Do not assume a supplier with 100% on-time
    delivery has no inventory-related risk.

    3. INVENTORY INTERPRETATION

    Do not label inventory as slow-moving solely
    because turnover is below a network average.

    Do not state that inventory is restricting
    cash flow without supporting financial data.

    Clearly distinguish:
    - Locations with stockout days greater than zero
    - Locations with zero closing inventory
    - Positive-stock locations below reorder point

    Do not use the count from one definition
    as the baseline for another.

    4. MONTH-OVER-MONTH COMPARISON

    Compare the current month with the
    previous reporting month.

    Include changes in:
    - Fill Rate
    - Stockout Rate
    - At-Risk Rate
    - Supplier On-Time Rate
    - Potential Gross Margin Exposure

    For percentage KPIs, express changes
    in percentage points.

    Discuss cases where network-level improvement
    coexists with local operational deterioration.

    Use only the provided month-level evidence.

    5. FINANCIAL ACCURACY

    Use Indian Rupees throughout.

    Clearly separate:
    - Potential unmet selling value
    - Potential gross margin exposure
    - Actual realized financial losses

    Never describe potential exposure as
    realized revenue or profit losses.

    Do not claim permanent customer churn
    or lost customers without supporting data.

    6. QUANTIFIED MANAGEMENT SCENARIO

    Provide one illustrative scenario:

    Network Fill Rate improves to 95%,
    assuming the current month's total
    demand remains unchanged.

    Calculate additional fulfilled units
    from the verified demand and fulfillment data.

    Estimate potential margin opportunity
    using the current average potential
    margin per unfulfilled unit.

    Clearly state:
    - Formula and substituted values
    - Assumptions
    - Limitations
    - This is illustrative, not a forecast

    7. RECOMMENDATIONS AND ACTION PLAN

    Give five prioritized actions with:
    - Verified issue and baseline
    - Specific proposed action
    - Proposed responsible owner
    - Timeframe
    - Illustrative KPI target
    - Improvement needed from baseline
    - Method for verifying success

    Supplier penalties must be conditional
    on contractual review.

    Warehouse stock transfers must be conditional
    on available transferable stock, transport
    feasibility and network service impacts.

    Avoid promising that targets will be achieved.

    8. EXECUTIVE REPORT COMPLETENESS

    Include:
    - Quantified executive summary
    - Top five business risks
    - Supplier reliability versus exposure
    - Financial implications
    - Month-over-month changes
    - Illustrative what-if scenario
    - Prioritized management action plan
    - Evidence limitations and confidence

    Preserve the existing machine-readable
    KPI and risk JSON structure exactly.

    Do not add a second fenced JSON block.
    """

    prompt += (
        "\n\nADDITIONAL VERIFIED BUSINESS CONTEXT:\n"
        + json.dumps(
            {
                "previous_month": previous_month,
                "supplier_performance": supplier_details
            },
            ensure_ascii=False,
            indent=2
        )
    )
    # Add corrective feedback only during a retry.
    if attempt > 1:

        errors = state.get("validation_errors", [])

        if not errors:
            raise ValueError(
                "Retry requested without validation errors."
            )

        prompt += (
            "\n\nCORRECTION REQUIRED:\n"
            "Your previous investigation failed validation.\n"
            "Correct every issue below using the verified evidence.\n"
            "Keep the complete executive report and JSON structure.\n"
            "Do not invent values to satisfy validation.\n\n"
            + json.dumps(errors, indent=2)
        )

        print(
            f"Sending {len(errors)} validation issue(s) "
            "back to Gemini"
        )
    response = client.models.generate_content(
        model="gemini-3.5-flash-lite",
        contents=prompt
    )

    if not response.text:
        raise ValueError("Gemini returned an empty response")

    return {
        "ai_analysis": response.text,
        "attempt_count": attempt
    }
# ==========================================
# NODE 6 — AUTOMATED AI DRAFT VALIDATION
# ==========================================
# ==========================================
# HELPER — VERIFY DETAILED RISK CLAIMS
# ==========================================

def check_risk_claims(risk_claims, priorities):

    errors = []

    specifications = {
        "workstreams": {
            "source": "top_category_warehouse_workstreams",
            "ids": ("category", "warehouse"),
            "metrics": (
                "fill_rate_pct",
                "potential_gross_margin_exposure"
            ),
            "count": 3
        },

        "suppliers": {
            "source": "lowest_on_time_suppliers",
            "ids": ("supplier_id",),
            "metrics": (
                "on_time_rate_pct",
                "eligible_deliveries"
            ),
            "count": 3
        },

        "sku_locations": {
            "source": "top_risk_sku_locations",
            "ids": ("sku_id", "warehouse"),
            "metrics": (
                "unfulfilled_units",
                "calculated_margin_exposure"
            ),
            "count": 5
        }
    }

    if not isinstance(risk_claims, dict):
        return ["risk_claims must be a JSON object."]

    if set(risk_claims) != set(specifications):
        errors.append(
            "risk_claims has missing or extra sections."
        )

    for section, spec in specifications.items():

        rows = risk_claims.get(section)

        if not isinstance(rows, list):
            errors.append(f"{section}: Expected a list.")
            continue

        expected_rows = priorities[
            spec["source"]
        ][:spec["count"]]

        if len(rows) != spec["count"]:
            errors.append(
                f"{section}: Expected {spec['count']} records, "
                f"received {len(rows)}."
            )

        id_fields = spec["ids"]
        metric_fields = spec["metrics"]

        expected_map = {
            tuple(row[field] for field in id_fields): row
            for row in expected_rows
        }

        seen = set()

        for row in rows:

            if not isinstance(row, dict):
                errors.append(
                    f"{section}: Invalid record."
                )
                continue

            required = set(id_fields) | set(metric_fields)

            if set(row) != required:
                errors.append(
                    f"{section}: Missing or extra fields."
                )

            identifiers = tuple(
                row.get(field) for field in id_fields
            )

            if not all(
                isinstance(value, str) and value
                for value in identifiers
            ):
                errors.append(
                    f"{section}: Invalid identifiers."
                )
                continue

            if identifiers in seen:
                errors.append(
                    f"{section}: Duplicate {identifiers}."
                )
                continue

            seen.add(identifiers)

            if identifiers not in expected_map:
                errors.append(
                    f"{section}: Unknown {identifiers}."
                )
                continue

            reference = expected_map[identifiers]

            for metric in metric_fields:

                actual = row.get(metric)
                expected = reference[metric]

                if (
                    isinstance(actual, bool)
                    or not isinstance(actual, (int, float))
                    or not math.isfinite(actual)
                ):
                    errors.append(
                        f"{section} {identifiers}: "
                        f"Invalid {metric}."
                    )

                elif abs(actual - expected) > 0.01:
                    errors.append(
                        f"{section} {identifiers}: "
                        f"{metric} AI={actual}, "
                        f"Verified={expected}"
                    )

        missing_records = set(expected_map) - seen

        if missing_records:
            errors.append(
                f"{section}: Missing records "
                f"{sorted(missing_records)}."
            )

    return errors
def validate_ai_draft(state: InvestigationState):

    print("NODE 6: Validating Gemini AI draft")

    analysis = state["ai_analysis"]

    errors = []

    
    # ==========================================
    # CHECK 1: CURRENCY VALIDATION
    # Ignore LaTeX math, reject genuine USD.
    # ==========================================

    def mask_latex_math(match):

        expression = match.group(1)

        if re.search(r"\\[A-Za-z]+|=", expression):
            return " " * len(match.group(0))

        return match.group(0)

    currency_scan_text = re.sub(
        r"\$([^\n$]+)\$",
        mask_latex_math,
        analysis
    )

    has_usd = bool(
        re.search(
            r"\bUSD\b|\bUS dollars?\b",
            analysis,
            re.IGNORECASE
        )
    )

    has_dollar_amount = bool(
        re.search(
            r"\$\s*[-+]?\s*\d",
            currency_scan_text
        )
    )

    if has_usd or has_dollar_amount:
        errors.append(
            "Incorrect currency detected: USD or $."
        )


    # CHECK 2: Require INR currency identification.
    if not re.search(
        r"₹|\bINR\b",
        analysis
    ):
        errors.append(
            "INR currency identification is missing."
        )

    # CHECK 3: Require the verified October fill rate.
    if not re.search(
        r"\b92\.87\s*%",
        analysis
    ):
        errors.append(
            "Verified October Fill Rate 92.87% is missing."
        )

    # CHECK 4: Require the verified stockout rate.
    if not re.search(
        r"\b21\.94\s*%",
        analysis
    ):
        errors.append(
            "Verified October Stockout Rate 21.94% is missing."
        )
    # ==========================================
    # CHECK 5: VERIFY ALL TEN STRUCTURED KPIs
    # ==========================================

    kpi_names = [
        "fill_rate_pct",
        "stockout_rate_pct",
        "at_risk_rate_pct",
        "supplier_on_time_rate_pct",
        "weighted_lead_time_days",
        "closing_inventory_value",
        "inventory_coverage_days",
        "inventory_turnover",
        "potential_unmet_sales",
        "potential_gross_margin_exposure",
    ]

    # Extract the JSON code block from Gemini's report.
    json_blocks = re.findall(
        r"```json\s*(.*?)\s*```",
        analysis,
        flags=re.IGNORECASE | re.DOTALL
    )

    if len(json_blocks) != 1:

        errors.append(
            "Expected exactly one JSON KPI block."
        )

    else:

        try:
            parsed = json.loads(json_blocks[0])

        except (json.JSONDecodeError, ValueError):
            errors.append(
                "Gemini returned invalid KPI JSON."
            )

        else:

            if (
                not isinstance(parsed, dict)
                or set(parsed.keys()) != {"kpi_claims", "risk_claims"}
                or not isinstance(
                    parsed.get("kpi_claims"), dict
                )
            ):
                errors.append(
                    "Incorrect KPI JSON structure."
                )

            else:

                claims = parsed["kpi_claims"]

                verified = state["brief"]["october_kpis"]

                missing = set(kpi_names) - set(claims)
                extra = set(claims) - set(kpi_names)

                if missing:
                    errors.append(
                        f"Missing KPI claims: {sorted(missing)}"
                    )

                if extra:
                    errors.append(
                        f"Unexpected KPI claims: {sorted(extra)}"
                    )

                for metric in kpi_names:

                    if metric not in claims:
                        continue

                    actual = claims[metric]
                    expected = verified[metric]

                    # Reject strings, booleans and invalid numbers.
                    if (
                        isinstance(actual, bool)
                        or not isinstance(actual, (int, float))
                        or not math.isfinite(actual)
                    ):
                        errors.append(
                            f"{metric}: Invalid numeric value."
                        )
                        continue

                    # Compare with verified SQL evidence.
                    if abs(actual - expected) > 0.01:
                        errors.append(
                            f"{metric}: AI={actual}, "
                            f"Verified={expected}"
                        )

                if not any(
                    "KPI claims" in error
                    or "Invalid numeric" in error
                    or "AI=" in error
                    for error in errors
                ):
                    print(
                        "STRUCTURED KPI COMPARISON: "
                        "10/10 MATCH"
                    )
                    # ==========================================
                # CHECK 6: VERIFY DETAILED RISK CLAIMS
                # ==========================================

                risk_errors = check_risk_claims(
                    parsed["risk_claims"],
                    state["brief"]["ranked_priorities"]
                )

                errors.extend(risk_errors)

                if not risk_errors:
                    print(
                        "DETAILED RISK COMPARISON: "
                        "11/11 RECORDS MATCH"
                    )
    passed = len(errors) == 0

    print(
        "AI DRAFT VALIDATION:",
        "PASS" if passed else "FAIL"
    )

    for error in errors:
        print("ISSUE:", error)

    return {
        "validated": passed,
        "validation_errors": errors
    }
# ==========================================
# CONDITIONAL ROUTER — AI QUALITY DECISION
# ==========================================

def route_after_validation(state: InvestigationState):

    # Case 1: The AI report passed validation.
    if state["validated"]:
        print("ROUTING: APPROVED")
        return "approved"

    # Case 2: Validation failed, but one retry remains.
    if state.get("attempt_count", 0) < 2:
        print("ROUTING: RETRY REQUIRED")
        return "retry"

    # Case 3: Both attempts failed.
    print("ROUTING: REJECTED AFTER MAX ATTEMPTS")
    return "rejected"
# ==========================================
# 3. CONSTRUCT THE LANGGRAPH
# ==========================================

builder = StateGraph(InvestigationState)

builder.add_node("load_evidence", load_evidence)
builder.add_node("validate_evidence", validate_evidence)
builder.add_node("prioritize_risks", prioritize_risks)
builder.add_node(
    "build_investigation_brief",
    build_investigation_brief
)
builder.add_node(
    "generate_ai_insights",
    generate_ai_insights
)
builder.add_node(
    "validate_ai_draft",
    validate_ai_draft
)
builder.add_edge(START, "load_evidence")

builder.add_edge(
    "load_evidence", "validate_evidence"
)

builder.add_edge(
    "validate_evidence", "prioritize_risks"
)

builder.add_edge(
    "prioritize_risks", "build_investigation_brief"
)

builder.add_edge(
    "build_investigation_brief",
    "generate_ai_insights"
)

builder.add_edge(
    "generate_ai_insights",
    "validate_ai_draft"
)

# ==========================================
# CONDITIONAL AI VALIDATION ROUTING
# ==========================================

builder.add_conditional_edges(
    "validate_ai_draft",
    route_after_validation,
    {
        "approved": END,
        "retry": "generate_ai_insights",
        "rejected": END
    }
)

graph = builder.compile()


# ==========================================
# 4. EXECUTE THE WORKFLOW
# ==========================================

if __name__ == "__main__":

    result = graph.invoke({})

    # ==========================================
    # FINAL AI REPORT APPROVAL SAFEGUARDS
    # ==========================================

    approved = result.get("validated") is True

    issues = result.get("validation_errors", [])

    attempts = result.get("attempt_count", 0)

    output_dir = ROOT / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Always preserve the latest generated draft.
    draft_file = (
        output_dir / "gemini_investigation_draft.md"
    )

    draft_file.write_text(
        "# AI Investigation Draft - Review Required\n\n"
        + result.get("ai_analysis", ""),
        encoding="utf-8"
    )

    print(
        "FINAL AI VALIDATION:",
        "PASS" if approved else "FAIL"
    )

    print("Gemini attempts:", attempts)
    print("Validation issues:", issues)

    # Save the final report according to its status.
    if approved:

        report_file = (
            output_dir / "gemini_investigation_approved.md"
        )

        report_file.write_text(
            "# AI Investigation Report\n\n"
            "**Structured evidence validation: PASSED**\n\n"
            + result["ai_analysis"],
            encoding="utf-8"
        )

    else:

        report_file = (
            output_dir / "gemini_investigation_rejected.md"
        )

        report_file.write_text(
            "# REJECTED AI REPORT - DO NOT USE\n\n"
            "**Structured evidence validation: FAILED**\n\n"
            + result.get("ai_analysis", ""),
            encoding="utf-8"
        )

    # Record the result of the latest execution.
    status_file = output_dir / "gemini_validation_status.json"

    status_file.write_text(
        json.dumps(
            {
                "validated": approved,
                "attempt_count": attempts,
                "validation_errors": issues,
                "latest_report": str(report_file)
            },
            indent=2
        ),
        encoding="utf-8"
    )

    print("Report:", report_file)
    print("Validation status file:", status_file)

    # Do not allow a rejected report to be
    # announced as a successful execution.
    if not approved:
        print("\nLANGGRAPH WORKFLOW: REJECTED")
        raise SystemExit(1)

    print("\nLANGGRAPH WORKFLOW: SUCCESS")

    priorities = result["priorities"]

    print(
        "Top 3 workstream exposure share:",
        priorities["top_three_exposure_share_pct"],
        "%"
    )

    print(
        "Priority workstreams:",
        len(priorities["top_category_warehouse_workstreams"])
    )

    print(
        "Supplier investigations:",
        len(priorities["lowest_on_time_suppliers"])
    )

    print(
        "Priority SKU locations:",
        len(priorities["top_risk_sku_locations"])
    )

    print("Output:", OUTPUT_FILE)