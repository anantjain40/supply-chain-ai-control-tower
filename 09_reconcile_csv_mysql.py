"""
Project 02 — Section 09.2: independent cleaned CSV -> MySQL CSV reconciliation.
Run from project root with: python 09_reconcile_csv_mysql.py

Required files (placed anywhere beneath the script's folder):
  inventory_clean.csv          suppliers_clean.csv
  inventory_db_export.csv      suppliers_db_export.csv

Export BOTH complete MySQL tables directly from DBeaver, using CSV with headers.
No database connection, new package, or source-file edits required.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from collections import Counter
from datetime import datetime
from decimal import Decimal, InvalidOperation, getcontext
from pathlib import Path

getcontext().prec = 38
ROOT = Path(__file__).resolve().parent
REPORT_DIR = ROOT / "reconciliation_09"
MAX_EXAMPLES = 10000
SKIP_DIRS = {".venv", "venv", ".git", "node_modules", "__pycache__", "reconciliation_09"}
NULL_MARKERS = {"", "null", "none", "nan", "<null>", "\\n"}
DATE_FORMATS = ("%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S.%f", "%Y/%m/%d", "%d/%m/%Y")
NUMERIC_EXPLICIT = {
    "opening_stock_units", "received_units", "demand_units", "fulfilled_units",
    "closing_stock_units", "reorder_point_units", "stockout_days",
    "unit_cost", "unit_selling_price", "replenishment_lead_time_days",
    "supplier_deliveries_count", "supplier_on_time_deliveries_count",
}
DATASETS = [
    ("inventory", "inventory_clean.csv", "inventory_db_export.csv", ("sku_id", "warehouse", "reporting_month")),
    ("suppliers", "suppliers_clean.csv", "suppliers_db_export.csv", ("supplier_id",)),
]


def locate(filename: str) -> Path:
    matches = [p for p in ROOT.rglob(filename) if not SKIP_DIRS.intersection(p.relative_to(ROOT).parts)]
    if not matches:
        raise FileNotFoundError(
            f"Missing {filename}. Put it anywhere inside your project folder ({ROOT}). "
            "MySQL exports must be complete CSVs with the column headers."
        )
    if len(matches) > 1:
        raise RuntimeError(f"More than one {filename} found. Keep one copy only:\n" + "\n".join(map(str, matches)))
    return matches[0]


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        sample = file.read(8192)
        file.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        except csv.Error:
            dialect = csv.excel
        reader = csv.DictReader(file, dialect=dialect)
        if not reader.fieldnames:
            raise ValueError(f"No column headers found in {path.name}")
        headers = [h.strip() if h is not None else "" for h in reader.fieldnames]
        if "" in headers or len(set(headers)) != len(headers):
            raise ValueError(f"Missing/duplicate column names in {path.name}: {headers}")
        rows: list[dict[str, str]] = []
        for n, record in enumerate(reader, start=2):
            if None in record:
                raise ValueError(f"{path.name}: CSV row {n} has more fields than the header. Check export separator/quotes.")
            rows.append({h: (record.get(original) or "") for h, original in zip(headers, reader.fieldnames)})
        return headers, rows


def blank(value: str | None) -> bool:
    return value is None or value.strip().lower() in NULL_MARKERS


def canonical_date(value: str) -> str:
    value = value.strip()
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(value, fmt).date().isoformat()
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).date().isoformat()
    except ValueError:
        return value  # Unrecognized date representation will be compared literally.


def numeric_column(name: str, source_rows: list[dict], db_rows: list[dict]) -> bool:
    if name in NUMERIC_EXPLICIT:
        return True
    if name.lower().endswith("_id") or name in {"sku_id", "supplier_id"}:
        return False
    seen = False
    for row in source_rows + db_rows:
        v = row.get(name, "")
        if blank(v):
            continue
        seen = True
        try:
            Decimal(v.strip())
        except InvalidOperation:
            return False
    return seen


def canonical(value: str | None, name: str, numeric: set[str]) -> str | None:
    if blank(value):
        return None
    assert value is not None
    if name in numeric:
        try:
            d = Decimal(value.strip())
            if not d.is_finite():
                return f"INVALID_NUMERIC:{value}"
            return str(d.normalize())  # '12', '12.0', '12.000' become the same.
        except InvalidOperation:
            return f"INVALID_NUMERIC:{value}"
    if name == "reporting_month" or name.lower().endswith("_date"):
        return canonical_date(value)
    return value  # Text is compared strictly, including whitespace/case.


def make_index(rows: list[dict], keys: tuple[str, ...], numeric: set[str]):
    index = {}
    duplicates = []
    null_keys = []
    for n, row in enumerate(rows, start=2):
        k = tuple(canonical(row.get(field), field, numeric) for field in keys)
        if any(item is None for item in k):
            null_keys.append({"line": n, "key": repr(k)})
            continue
        if k in index:
            duplicates.append({"line": n, "key": repr(k)})
        else:
            index[k] = row
    return index, duplicates, null_keys


def as_number(row: dict, name: str) -> Decimal:
    value = row.get(name)
    if blank(value):
        return Decimal(0)
    return Decimal(str(value).strip())


def financial_totals(rows: list[dict], dataset_name: str):
    if dataset_name != "inventory":
        return None
    required = {"reporting_month", "demand_units", "fulfilled_units", "unit_cost", "unit_selling_price", "stockout_days", "supplier_on_time_deliveries_count", "supplier_deliveries_count", "replenishment_lead_time_days"}
    if rows and not required.issubset(rows[0]):
        return {"error": f"Missing metric columns: {sorted(required - rows[0].keys())}"}
    totals = {key: Decimal(0) for key in (
        "historical_demand", "historical_fulfilled", "historical_unfulfilled",
        "historical_stockout_location_months", "historical_potential_margin_inr",
        "october_demand", "october_fulfilled", "october_unfulfilled",
        "october_potential_margin_inr",
    )}
    unknown_ontime = missing_lead_with_deliveries = 0
    try:
        for row in rows:
            demand, fulfilled = as_number(row, "demand_units"), as_number(row, "fulfilled_units")
            unmet = demand - fulfilled
            margin = unmet * max(as_number(row, "unit_selling_price") - as_number(row, "unit_cost"), Decimal(0))
            totals["historical_demand"] += demand
            totals["historical_fulfilled"] += fulfilled
            totals["historical_unfulfilled"] += unmet
            totals["historical_potential_margin_inr"] += margin
            if as_number(row, "stockout_days") > 0:
                totals["historical_stockout_location_months"] += 1
            if blank(row.get("supplier_on_time_deliveries_count")):
                unknown_ontime += 1
            if as_number(row, "supplier_deliveries_count") > 0 and blank(row.get("replenishment_lead_time_days")):
                missing_lead_with_deliveries += 1
            if canonical_date(str(row.get("reporting_month", ""))) == "2026-10-01":
                totals["october_demand"] += demand
                totals["october_fulfilled"] += fulfilled
                totals["october_unfulfilled"] += unmet
                totals["october_potential_margin_inr"] += margin
        return {**{k: str(v) for k, v in totals.items()},
                "unknown_ontime": unknown_ontime,
                "missing_lead_time_with_deliveries": missing_lead_with_deliveries}
    except (InvalidOperation, ValueError) as e:
        return {"error": f"Cannot calculate financial totals: {e}"}


def audit_one(name: str, source_file: str, db_file: str, keys: tuple[str, ...], details: list[dict]):
    source_path, db_path = locate(source_file), locate(db_file)
    src_headers, src_rows = read_csv(source_path)
    db_headers, db_rows = read_csv(db_path)
    missing_columns = sorted(set(src_headers) - set(db_headers))
    extra_columns = sorted(set(db_headers) - set(src_headers))
    missing_keys = sorted(set(keys) - set(src_headers))
    missing_keys_db = sorted(set(keys) - set(db_headers))
    if missing_keys or missing_keys_db:
        raise ValueError(f"{name}: business key columns missing in export(s). Source missing {missing_keys}, DB missing {missing_keys_db}.")
    common = sorted(set(src_headers) & set(db_headers))
    numeric = {col for col in common if numeric_column(col, src_rows, db_rows)}
    src_index, src_dupes, src_null_keys = make_index(src_rows, keys, numeric)
    db_index, db_dupes, db_null_keys = make_index(db_rows, keys, numeric)
    source_only = sorted(src_index.keys() - db_index.keys(), key=str)
    db_only = sorted(db_index.keys() - src_index.keys(), key=str)
    mismatch_count = 0
    mismatch_columns = Counter()
    for k in source_only:
        if len(details) < MAX_EXAMPLES:
            details.append({"table": name, "issue": "Missing in MySQL", "key": repr(k), "column": "", "clean_csv": "", "mysql_export": ""})
    for k in db_only:
        if len(details) < MAX_EXAMPLES:
            details.append({"table": name, "issue": "Extra in MySQL", "key": repr(k), "column": "", "clean_csv": "", "mysql_export": ""})
    for k in src_index.keys() & db_index.keys():
        src, db = src_index[k], db_index[k]
        for col in common:
            left, right = canonical(src.get(col), col, numeric), canonical(db.get(col), col, numeric)
            if left != right:
                mismatch_count += 1
                mismatch_columns[col] += 1
                if len(details) < MAX_EXAMPLES:
                    details.append({"table": name, "issue": "Value mismatch", "key": repr(k), "column": col,
                                    "clean_csv": str(left), "mysql_export": str(right)})
    metrics_source = financial_totals(src_rows, name)
    metrics_database = financial_totals(db_rows, name)
    # Numeric totals are compared as Decimal values, so CSV formatting differences
    # such as 123.50 versus 123.5000 cannot create false mismatches.
    metrics_match = (metrics_source == metrics_database) if name != "inventory" else (
        isinstance(metrics_source, dict) and isinstance(metrics_database, dict)
        and "error" not in metrics_source and "error" not in metrics_database
        and set(metrics_source) == set(metrics_database)
        and all(
            Decimal(str(metrics_source[k])) == Decimal(str(metrics_database[k]))
            for k in metrics_source
        )
    )
    baseline_ok = True
    if name == "inventory":
        expected = {
            "historical_unfulfilled": Decimal(36424),
            "historical_stockout_location_months": Decimal(815),
            "historical_potential_margin_inr": Decimal("33058084.60"),
            "october_demand": Decimal(51603),
            "october_fulfilled": Decimal(47922),
            "october_unfulfilled": Decimal(3681),
            "october_potential_margin_inr": Decimal("3071205.83"),
        }
        if not metrics_source or "error" in metrics_source or not metrics_database or "error" in metrics_database:
            baseline_ok = False
        else:
            for metrics in (metrics_source, metrics_database):
                for field, expected_val in expected.items():
                    if abs(Decimal(metrics[field]) - expected_val) >= Decimal("0.01"):
                        baseline_ok = False
                if metrics["unknown_ontime"] != 7 or metrics["missing_lead_time_with_deliveries"] != 15:
                    baseline_ok = False
    expected_rows = 4320 if name == "inventory" else 12
    status = "PASS" if all((
        len(src_rows) == expected_rows, len(db_rows) == expected_rows,
        not missing_columns, not extra_columns, not src_dupes, not db_dupes,
        not src_null_keys, not db_null_keys, not source_only, not db_only,
        mismatch_count == 0, metrics_match, baseline_ok,
    )) else "FAIL"
    return {
        "status": status,
        "files": {"clean_csv": str(source_path.relative_to(ROOT)), "mysql_export": str(db_path.relative_to(ROOT))},
        "rows": {"clean_csv": len(src_rows), "mysql_export": len(db_rows), "expected_each": expected_rows},
        "columns": {"clean_csv": len(src_headers), "mysql_export": len(db_headers),
                    "missing_from_mysql": missing_columns, "extra_in_mysql": extra_columns},
        "keys": list(keys),
        "duplicate_business_keys": {"clean_csv": len(src_dupes), "mysql_export": len(db_dupes)},
        "blank_business_keys": {"clean_csv": len(src_null_keys), "mysql_export": len(db_null_keys)},
        "records_missing_from_mysql": len(source_only),
        "unexpected_mysql_records": len(db_only),
        "cell_value_mismatches": mismatch_count,
        "mismatches_by_column": dict(sorted(mismatch_columns.items())),
        "aggregate_metrics_match": metrics_match,
        "verified_project_benchmarks_match": baseline_ok,
        "financial_metrics_clean_csv": metrics_source,
        "financial_metrics_mysql_export": metrics_database,
    }


def main() -> int:
    print("\nSECTION 09.2 — INDEPENDENT CLEAN CSV / MYSQL RECONCILIATION")
    print("Project root:", ROOT)
    details: list[dict] = []
    reports = {}
    try:
        for name, source_file, db_file, keys in DATASETS:
            reports[name] = audit_one(name, source_file, db_file, keys, details)
    except (FileNotFoundError, RuntimeError, ValueError, UnicodeError, csv.Error) as error:
        print("\nSETUP / FILE ERROR:", error)
        print("\nRequired: inventory_clean.csv, suppliers_clean.csv, inventory_db_export.csv, suppliers_db_export.csv")
        return 2
    passed = all(report["status"] == "PASS" for report in reports.values())
    result = {
        "section": "09.2 Independent CSV-to-MySQL reconciliation",
        "overall_status": "PASS" if passed else "FAIL",
        "tables": reports,
        "note": "Financial exposure is modeled, not booked accounting loss. Compare complete exports, not DBeaver preview rows.",
        "detailed_examples_saved": len(details),
        "detailed_examples_cap": MAX_EXAMPLES,
    }
    REPORT_DIR.mkdir(exist_ok=True)
    json_file = REPORT_DIR / "09_reconciliation_results.json"
    detail_file = REPORT_DIR / "09_mismatch_details.csv"
    json_file.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    with detail_file.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["table", "issue", "key", "column", "clean_csv", "mysql_export"])
        writer.writeheader()
        writer.writerows(details)
    print("\nTable     Clean rows   MySQL rows   Missing   Extra   Cell mismatches   Status")
    for name, result_table in reports.items():
        print(f"{name:<10}{result_table['rows']['clean_csv']:<13}{result_table['rows']['mysql_export']:<13}"
              f"{result_table['records_missing_from_mysql']:<10}{result_table['unexpected_mysql_records']:<8}"
              f"{result_table['cell_value_mismatches']:<18}{result_table['status']}")
    print("\nOVERALL SOURCE-TO-DATABASE RESULT:", result["overall_status"])
    print("JSON report:", json_file)
    print("Mismatch details:", detail_file)
    if not passed:
        print("Discrepancies detected. Review JSON and mismatch CSV. Do not sign off yet.")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
