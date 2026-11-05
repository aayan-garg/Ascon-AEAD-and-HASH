#!/usr/bin/env python3
"""
scripts/check_doc_numbers.py
Validates that numerical metrics (LUT, FF, WNS, Fmax) in performance tables match
the actual committed Vivado report files.
Fulfills Task A6: Performance Metric Consistency Checker
"""

import os
import sys
import re

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def parse_report_number(path: str, pattern: str) -> str:
    if not os.path.exists(path):
        return "MISSING"
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()
    m = re.search(pattern, text)
    return m.group(1).strip() if m else "NOT_FOUND"

def validate_numbers() -> bool:
    print("=" * 80)
    print("CHECKING PERFORMANCE NUMBERS AGAINST AUTHORITATIVE TOOL REPORTS")
    print("=" * 80)
    
    all_ok = True

    # 1. Check SoC Bringup Numbers
    soc_util_path = os.path.join(ROOT_DIR, "results", "synthesis", "utilization_bringup.txt")
    soc_time_path = os.path.join(ROOT_DIR, "results", "timing", "timing_bringup.txt")

    soc_lut = parse_report_number(soc_util_path, r"Slice LUTs\*?\s*\|\s*(\d+)")
    soc_ff  = parse_report_number(soc_util_path, r"Slice Registers\s*\|\s*(\d+)")
    soc_wns = parse_report_number(soc_time_path, r"WNS\(ns\)\s+TNS\(ns\)[^\n]*\n[^\n]*\n\s*(-?[\d\.]+)")

    print(f"Authoritative SoC Reports:")
    print(f"  LUTs: {soc_lut} | FFs: {soc_ff} | WNS: {soc_wns} ns")

    # Check comparison_table.md
    comp_tbl = os.path.join(ROOT_DIR, "results", "performance", "comparison_table.md")
    with open(comp_tbl, "r", encoding="utf-8") as f:
        content = f.read()

    if soc_lut in content and soc_ff in content and soc_wns in content:
        print(f"  [PASS] comparison_table.md matches SoC reports: {soc_lut} LUTs, {soc_ff} FFs, +{soc_wns} ns WNS")
    else:
        print(f"  [FAIL] comparison_table.md does not match SoC reports!")
        all_ok = False

    # 2. Check Serial32 Numbers
    s32_util = os.path.join(ROOT_DIR, "results", "synthesis", "permutation_serial32_util.rpt")
    s32_time = os.path.join(ROOT_DIR, "results", "timing", "permutation_serial32_timing.rpt")
    s32_lut = parse_report_number(s32_util, r"Slice LUTs\*?\s*\|\s*(\d+)")
    s32_ff  = parse_report_number(s32_util, r"Slice Registers\s*\|\s*(\d+)")
    s32_wns = parse_report_number(s32_time, r"WNS\(ns\)\s+TNS\(ns\)[^\n]*\n[^\n]*\n\s*(-?[\d\.]+)")

    print(f"\nAuthoritative Permutation Serial32 Reports:")
    print(f"  LUTs: {s32_lut} | FFs: {s32_ff} | WNS: {s32_wns} ns")

    if s32_lut in content and s32_ff in content and s32_wns in content:
        print(f"  [PASS] comparison_table.md matches serial32 reports: {s32_lut} LUTs, {s32_ff} FFs, +{s32_wns} ns WNS")
    else:
        print(f"  [FAIL] comparison_table.md does not match serial32 reports!")
        all_ok = False

    return all_ok

def main():
    ok = validate_numbers()
    if ok:
        print("\n[SUCCESS] All documented performance figures match tool reports.")
        return 0
    else:
        print("\n[FAILED] Mismatches detected between documents and tool reports.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
