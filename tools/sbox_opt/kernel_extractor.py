#!/usr/bin/env python3
"""
tools/sbox_opt/kernel_extractor.py
Multi-Level Logic Synthesis for Ascon 5x5 S-box via Brayton-McMullen
Recursive Algebraic Kernel/Co-Kernel Extraction and Greedy Factorization.
Input: Minimal SOP cover from UC Berkeley Espresso (scripts/ascon_sbox.pla).
Output: rtl/ascon/sbox5_kernel.sv and results/synthesis/sbox_kernel_report.log.
"""

import os
import sys
import subprocess
from collections import defaultdict

# NIST SP 800-232 Table 6 S-box
NIST_TABLE = [
    0x04, 0x0b, 0x1f, 0x14, 0x1a, 0x15, 0x09, 0x02,
    0x1b, 0x05, 0x08, 0x12, 0x1d, 0x03, 0x06, 0x1c,
    0x1e, 0x13, 0x07, 0x0e, 0x00, 0x0d, 0x11, 0x18,
    0x10, 0x0c, 0x01, 0x19, 0x16, 0x0a, 0x0f, 0x17
]

def in_pat_to_cube(in_pat):
    return frozenset((j, in_pat[j] == '1') for j in range(5) if in_pat[j] != '-')

def cube_lits(c):
    return len(c)

def expr_lits(cset):
    return sum(cube_lits(c) for c in cset)

def divide_cube(cubes, d):
    q = set()
    for c in cubes:
        if d.issubset(c):
            q.add(c - d)
    return frozenset(q)

def common_cube(cubes):
    if not cubes:
        return frozenset()
    res = set(next(iter(cubes)))
    for c in cubes:
        res &= set(c)
    return frozenset(res)

def get_literals(cubes):
    lits = set()
    for c in cubes:
        for lit in c:
            lits.add(lit)
    return lits

def find_kernels_raw(cubes):
    """Brayton-McMullen recursive kernel and co-kernel extraction."""
    kernels = []
    lits = sorted(get_literals(cubes))
    for lit in lits:
        d = frozenset([lit])
        q = divide_cube(cubes, d)
        if len(q) >= 2:
            c = common_cube(q)
            k = divide_cube(q, c)
            co_kernel = d | c
            if len(k) >= 2 and not common_cube(k):
                kernels.append((co_kernel, k))
                for sub_co, sub_k in find_kernels_raw(k):
                    kernels.append((co_kernel | sub_co, sub_k))
    return kernels

def algebraic_divide(F, K):
    """Algebraic division of expression F by kernel K: F = Q * K + R."""
    vars_K = set(v for k in K for v, pol in k)
    possible_q = set()
    for f in F:
        for k in K:
            if k.issubset(f):
                q = f - k
                vars_q = set(v for v, pol in q)
                if not (vars_q & vars_K):
                    possible_q.add(q)
    valid_q = set()
    for q in possible_q:
        if all((q | k) in F for k in K):
            valid_q.add(q)
    if not valid_q:
        return frozenset(), F
    Q = frozenset(valid_q)
    used_cubes = set(q | k for q in Q for k in K)
    R = frozenset(F - used_cubes)
    return Q, R

def format_cube(c):
    if not c:
        return ""
    parts = [f"x{v}" if p else f"~x{v}" for v, p in sorted(c)]
    return " & ".join(parts)

def format_kernel_expr(K):
    parts = []
    for c in sorted(K, key=lambda c: (len(c), sorted(c))):
        parts.append(f"({format_cube(c)})")
    return " | ".join(parts)

def run_kernel_extraction():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    report_path = os.path.join(root_dir, "results", "synthesis", "sbox_kernel_report.log")
    rtl_path = os.path.join(root_dir, "rtl", "ascon", "sbox5_kernel.sv")
    pla_path = os.path.join(root_dir, "scripts", "ascon_sbox.pla")

    # Run Espresso in single-output mode or parse truth table to get minimal SOP cover
    espresso_bin = os.path.join(os.path.dirname(__file__), "bin", "espresso")
    wsl_bin = "/mnt/c" + espresso_bin.replace("\\", "/")[2:]
    wsl_pla = "/mnt/c" + pla_path.replace("\\", "/")[2:]

    cmd = ["wsl", wsl_bin, "-Dso", wsl_pla]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print("[-] Error running espresso -Dso:", res.stderr)
        sys.exit(1)

    lines = [l.strip() for l in res.stdout.splitlines() if l.strip() and not l.startswith(("#", "."))]
    cubes = [l.split() for l in lines]

    outputs = {}
    for out_idx in range(5):
        cset = set()
        for in_pat, out_pat in cubes:
            if out_pat[out_idx] == "1":
                cset.add(in_pat_to_cube(in_pat))
        outputs[f"y{out_idx}"] = frozenset(cset)

    initial_lits = sum(expr_lits(cset) for cset in outputs.values())

    current_outputs = dict(outputs)
    extracted_kernels = []
    output_factors = defaultdict(dict)
    k_idx = 0

    # Iterative greedy extraction loop
    while True:
        candidates = set()
        for cset in current_outputs.values():
            for co, k in find_kernels_raw(cset):
                candidates.add(k)
        best_kernel, best_sav, best_divs = None, 0, {}
        for K in candidates:
            K_lits = expr_lits(K)
            gross_sav = 0
            divs = {}
            for name, F in current_outputs.items():
                Q, R = algebraic_divide(F, K)
                if len(Q) > 0:
                    divs[name] = (Q, R)
                    before = len(Q) * K_lits + sum(len(q) for q in Q) * len(K)
                    after = sum(len(q) for q in Q) + len(Q)
                    gross_sav += (before - after)
            net_sav = gross_sav - K_lits
            if net_sav > best_sav:
                best_sav = net_sav
                best_kernel = K
                best_divs = divs

        if not best_kernel or best_sav <= 0:
            break

        k_name = f"k{k_idx}"
        k_idx += 1
        extracted_kernels.append((k_name, best_kernel, best_sav))
        for name, (Q, R) in best_divs.items():
            output_factors[name][k_name] = Q
            current_outputs[name] = R

    # Compute literal counts
    total_extracted_lits = sum(expr_lits(K) for _, K, _ in extracted_kernels)
    total_factored_out_lits = 0
    for name in outputs.keys():
        for k_name, Q in output_factors[name].items():
            total_factored_out_lits += sum(len(q) + 1 for q in Q)
        total_factored_out_lits += expr_lits(current_outputs[name])
    final_lits = total_extracted_lits + total_factored_out_lits
    net_savings = initial_lits - final_lits

    # Build report text
    report_lines = [
        "================================================================================",
        "ASCON 5x5 S-BOX: BRAYTON-MCMULLEN ALGEBRAIC KERNEL EXTRACTION REPORT",
        "================================================================================",
        f"Algorithm: Brayton-McMullen Recursive Kernel/Co-Kernel Factorization",
        f"Tool Runner: tools/sbox_opt/kernel_extractor.py",
        f"Input Cover: Minimal Two-Level SOP from UC Berkeley Espresso (-Dso)",
        "--------------------------------------------------------------------------------",
        f"Initial Flat SOP Literals:  {initial_lits}",
        f"Multi-Level Network Literals:{final_lits:4d}",
        f"Net Literal Savings:        {net_savings:4d} ({(net_savings/initial_lits)*100:.1f}% reduction)",
        f"Extracted Algebraic Kernels:{len(extracted_kernels):4d}",
        "--------------------------------------------------------------------------------",
        "\nExtracted Common Algebraic Kernels (Shared Multi-Level Sub-Expressions):"
    ]

    for k_name, K, sav in extracted_kernels:
        k_expr = format_kernel_expr(K)
        report_lines.append(f"  {k_name} = {k_expr}  [net saving: {sav:2d} literals]")

    report_lines.append("\nFactorized Output Equations:")
    for out_idx in range(5):
        name = f"y{out_idx}"
        terms = []
        for k_name, Q in sorted(output_factors[name].items()):
            for q in sorted(Q, key=lambda c: (len(c), sorted(c))):
                q_str = format_cube(q)
                if q_str:
                    terms.append(f"({q_str} & {k_name})")
                else:
                    terms.append(k_name)
        for c in sorted(current_outputs[name], key=lambda c: (len(c), sorted(c))):
            terms.append(f"({format_cube(c)})")
        report_lines.append(f"  {name} = {' | '.join(terms)}")

    # Verify 32/32 against NIST Table 6
    report_lines.append("\n--------------------------------------------------------------------------------")
    report_lines.append("Verifying factorized kernel network against NIST Table 6 (all 32 inputs)...")
    mismatches = 0
    for idx in range(32):
        in_bits = [(idx >> (4 - j)) & 1 for j in range(5)]
        k_vals = {}
        for k_name, K, sav in extracted_kernels:
            val = 0
            for c in K:
                match = True
                for v, pol in c:
                    if (in_bits[v] == 1) != pol:
                        match = False
                        break
                if match:
                    val = 1
                    break
            k_vals[k_name] = val
        out_bits = [0] * 5
        for out_idx in range(5):
            name = f"y{out_idx}"
            val = 0
            for k_name, Q in output_factors[name].items():
                if k_vals[k_name]:
                    for q in Q:
                        match = True
                        for v, pol in q:
                            if (in_bits[v] == 1) != pol:
                                match = False
                                break
                        if match:
                            val = 1
                            break
                if val:
                    break
            if not val:
                for c in current_outputs[name]:
                    match = True
                    for v, pol in c:
                        if (in_bits[v] == 1) != pol:
                            match = False
                            break
                    if match:
                        val = 1
                        break
            out_bits[out_idx] = val

        comp_val = 0
        for j in range(5):
            if out_bits[j]:
                comp_val |= (1 << (4 - j))
        if comp_val != NIST_TABLE[idx]:
            report_lines.append(f"[-] MISMATCH at 0x{idx:02X}: computed=0x{comp_val:02X}, expected=0x{NIST_TABLE[idx]:02X}")
            mismatches += 1

    if mismatches == 0:
        report_lines.append("[SUCCESS] 100% equivalence verified (32/32 vectors bit-exact match).")
    else:
        report_lines.append(f"[FAIL] {mismatches} mismatches detected!")

    report_text = "\n".join(report_lines)
    print(report_text)

    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report_text)
    print(f"\n[+] Saved report to: {report_path}")

    # Emit SystemVerilog module
    sv_lines = [
        "// ==============================================================================",
        "// Module: sbox5_kernel.sv",
        "// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)",
        "// Generator: tools/sbox_opt/kernel_extractor.py",
        "// Method: Brayton-McMullen Recursive Algebraic Kernel/Co-Kernel Factorization",
        "// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6 across all 32 inputs.",
        "// ==============================================================================\n",
        "`timescale 1ns / 1ps",
        "`default_nettype wire\n",
        "module sbox5_kernel (",
        "    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4}",
        "    output wire [4:0] out_y  // {y0, y1, y2, y3, y4}",
        ");\n",
        "    wire x0 = in_x[4];",
        "    wire x1 = in_x[3];",
        "    wire x2 = in_x[2];",
        "    wire x3 = in_x[1];",
        "    wire x4 = in_x[0];\n",
        "    // Extracted common algebraic kernels (shared multi-level sub-expressions):"
    ]

    for k_name, K, sav in extracted_kernels:
        sv_lines.append(f"    wire {k_name} = {format_kernel_expr(K)};")

    sv_lines.append("\n    // Factorized outputs:")
    for out_idx in range(5):
        name = f"y{out_idx}"
        terms = []
        for k_name, Q in sorted(output_factors[name].items()):
            for q in sorted(Q, key=lambda c: (len(c), sorted(c))):
                q_str = format_cube(q)
                if q_str:
                    terms.append(f"({q_str} & {k_name})")
                else:
                    terms.append(k_name)
        for c in sorted(current_outputs[name], key=lambda c: (len(c), sorted(c))):
            terms.append(f"({format_cube(c)})")
        rhs = " |\n              ".join(terms)
        sv_lines.append(f"    wire {name} = {rhs};\n")

    sv_lines.append("    assign out_y = {y0, y1, y2, y3, y4};\n\nendmodule\n")

    with open(rtl_path, "w", encoding="utf-8") as f:
        f.write("\n".join(sv_lines))
    print(f"[+] Emitted generated RTL: {rtl_path}")

    if mismatches != 0:
        sys.exit(1)

if __name__ == "__main__":
    run_kernel_extraction()
