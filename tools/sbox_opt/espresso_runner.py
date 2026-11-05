#!/usr/bin/env python3
"""
tools/sbox_opt/espresso_runner.py
Two-Level Logic Minimization for Ascon 5x5 S-box using Quine-McCluskey / SOPform.
Reproduces minimal Sum-of-Products (SOP) boolean covers for NIST SP 800-232 Table 6.
"""

import sys
import sympy
from sympy.logic import SOPform
from sympy import symbols

# NIST SP 800-232 Table 6 S-box
NIST_TABLE = [
    0x04, 0x0b, 0x1f, 0x14, 0x1a, 0x15, 0x09, 0x02,
    0x1b, 0x05, 0x08, 0x12, 0x1d, 0x03, 0x06, 0x1c,
    0x1e, 0x13, 0x07, 0x0e, 0x00, 0x0d, 0x11, 0x18,
    0x10, 0x0c, 0x01, 0x19, 0x16, 0x0a, 0x0f, 0x17
]

def run_espresso_minimization():
    x0, x1, x2, x3, x4 = symbols('x0 x1 x2 x3 x4')
    variables = [x0, x1, x2, x3, x4]

    print("================================================================================")
    print("ASCON 5x5 S-BOX: TWO-LEVEL LOGIC MINIMIZATION (ESPRESSO / SOPFORM)")
    print("================================================================================")

    sop_results = {}
    term_counts = {}
    total_literals = 0

    for bit in range(5):
        minterms = []
        for idx, val in enumerate(NIST_TABLE):
            if (val >> (4 - bit)) & 1:
                b = [(idx >> (4 - j)) & 1 for j in range(5)]
                minterms.append(b)
        
        sop = SOPform(variables, minterms)
        sop_results[f"y{bit}"] = sop
        # Count terms
        terms = sop.args if isinstance(sop, sympy.Or) else [sop]
        term_counts[f"y{bit}"] = len(terms)
        
        # Count literals
        lit_count = 0
        for term in terms:
            factors = term.args if isinstance(term, sympy.And) else [term]
            lit_count += len(factors)
        total_literals += lit_count

        print(f"\n[y{bit}] Minimal SOP ({len(terms)} product terms, {lit_count} literals):")
        print(f"  y{bit} = {sop}")

    print("\n--------------------------------------------------------------------------------")
    print(f"Total Product Terms: {sum(term_counts.values())}")
    print(f"Total Literals:      {total_literals}")
    print("--------------------------------------------------------------------------------")

    # Verify against all 32 inputs
    print("\nVerifying minimized SOP covers against NIST Table 6 across all 32 inputs...")
    mismatches = 0
    for idx in range(32):
        in_vals = {
            x0: bool((idx >> 4) & 1),
            x1: bool((idx >> 3) & 1),
            x2: bool((idx >> 2) & 1),
            x3: bool((idx >> 1) & 1),
            x4: bool((idx >> 0) & 1)
        }
        computed_y = 0
        for bit in range(5):
            eval_val = bool(sop_results[f"y{bit}"].subs(in_vals))
            if eval_val:
                computed_y |= (1 << (4 - bit))
        
        expected_y = NIST_TABLE[idx]
        if computed_y != expected_y:
            print(f"[-] MISMATCH at input 0x{idx:02X}: computed=0x{computed_y:02X}, expected=0x{expected_y:02X}")
            mismatches += 1

    if mismatches == 0:
        print("[SUCCESS] 100% equivalence verified (32/32 vectors bit-exact match).")
    else:
        print(f"[FAIL] {mismatches} mismatches detected!")
        sys.exit(1)

    return sop_results, term_counts, total_literals

if __name__ == "__main__":
    run_espresso_minimization()

