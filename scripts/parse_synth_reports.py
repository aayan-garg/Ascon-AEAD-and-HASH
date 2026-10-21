#!/usr/bin/env python3
# ==============================================================================
# Script: parse_synth_reports.py
# Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
# Purpose: Extract utilization and timing metrics from Vivado reports and
#          compute exact cryptographic throughput and efficiency figures.
# ==============================================================================

import os
import re
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
SYNTH_DIR = ROOT_DIR / "results" / "synthesis"
TIMING_DIR = ROOT_DIR / "results" / "timing"
PERF_DIR = ROOT_DIR / "results" / "performance"

VARIANTS = [
    {
        "id": "permutation_1r",
        "name": "1-Round Iterative (Baseline)",
        "sbox": "Canonical Bit-sliced (Lut-5)",
        "cycles_aead": 6,   # b = 6 rounds
        "cycles_hash": 12,  # a = 12 rounds
        "desc": "Baseline 1-round/cycle datapath with NIST SP 800-232 bit-sliced S-box."
    },
    {
        "id": "permutation_2r",
        "name": "2-Rounds Unrolled (High Throughput)",
        "sbox": "Dual Cascaded Bit-sliced",
        "cycles_aead": 3,   # 6 rounds in 3 cycles
        "cycles_hash": 6,   # 12 rounds in 6 cycles
        "desc": "Chained dual combinational round cores retiring 2 rounds per clock edge."
    },
    {
        "id": "permutation_half",
        "name": "1/2-Round Folded (Low Area / Pipelined)",
        "sbox": "Time-Multiplexed Bit-sliced",
        "cycles_aead": 12,  # 6 rounds in 12 cycles
        "cycles_hash": 24,  # 12 rounds in 24 cycles
        "desc": "2-phase folded micro-step datapath (p_C + p_S in cycle 0, p_L in cycle 1)."
    },
    {
        "id": "permutation_1r_espresso",
        "name": "1-Round Espresso (Paper Variant)",
        "sbox": "Berkeley ESPRESSO Minimized SOP",
        "cycles_aead": 6,   # b = 6 rounds
        "cycles_hash": 12,  # a = 12 rounds
        "desc": "Paper-derived variant using 2-level SOP logic minimization for S-box layer."
    }
]

def parse_utilization(util_path):
    """Extracts LUT, FF, BRAM, and DSP counts from a Vivado utilization report."""
    if not os.path.exists(util_path):
        return None
    
    with open(util_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    luts = None
    ffs = None
    bram = 0
    dsp = 0
    
    # 1. Slice LUTs: | Slice LUTs | 1001 |
    lut_match = re.search(r"\|\s*Slice LUTs\s*\|\s*(\d+)\s*\|", content)
    if lut_match:
        luts = int(lut_match.group(1))
    else:
        # Fallback to LUT as Logic
        lut_logic = re.search(r"\|\s*LUT as Logic\s*\|\s*(\d+)\s*\|", content)
        if lut_logic:
            luts = int(lut_logic.group(1))

    # 2. Slice Registers / Flip Flops: | Slice Registers | 569 |
    ff_match = re.search(r"\|\s*Slice Registers\s*\|\s*(\d+)\s*\|", content)
    if ff_match:
        ffs = int(ff_match.group(1))
    else:
        ff_alt = re.search(r"\|\s*Register as Flip Flop\s*\|\s*(\d+)\s*\|", content)
        if ff_alt:
            ffs = int(ff_alt.group(1))

    # 3. Block RAM Tile: | Block RAM Tile | 4 |
    bram_match = re.search(r"\|\s*Block RAM Tile\s*\|\s*(\d+)\s*\|", content)
    if bram_match:
        bram = int(bram_match.group(1))

    # 4. DSPs: | DSPs | 0 |
    dsp_match = re.search(r"\|\s*DSPs\s*\|\s*(\d+)\s*\|", content)
    if dsp_match:
        dsp = int(dsp_match.group(1))

    return {
        "luts": luts,
        "ffs": ffs,
        "bram": bram,
        "dsp": dsp
    }

def parse_timing(timing_path):
    """Extracts WNS, checks timing status, and computes Fmax."""
    if not os.path.exists(timing_path):
        return None
    
    with open(timing_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    wns = None
    target_period = 10.000  # 100 MHz target constraint

    for i, line in enumerate(lines):
        if "Design Timing Summary" in line:
            # Look for the header row with WNS(ns)
            for j in range(i + 1, min(i + 15, len(lines))):
                if "WNS(ns)" in lines[j]:
                    # Next line after separator has the numbers
                    val_line = lines[j + 2].strip()
                    parts = val_line.split()
                    if parts:
                        try:
                            wns = float(parts[0])
                        except ValueError:
                            pass
                    break
            break

    if wns is None:
        # Regex search fallback
        match = re.search(r"WNS\(ns\)\s+TNS\(ns\)[^\n]*\n[^\n]*\n\s*([-\d\.]+)", "".join(lines))
        if match:
            wns = float(match.group(1))

    if wns is None:
        return None

    # Calculate Fmax (routed)
    # Tmin = Target_Period - WNS
    t_min = target_period - wns
    f_max = (1000.0 / t_min) if t_min > 0 else 0.0
    timing_met = (wns >= 0.0)

    return {
        "target_period": target_period,
        "wns": wns,
        "timing_met": timing_met,
        "f_max": f_max,
        "t_min": t_min
    }

def compute_throughputs(variant, f_mhz):
    """
    Computes cryptographic throughputs in Mbit/s.
    SP 800-232 Rates:
      AEAD-128: Rate = 64 bits/block
      Hash-256: Rate = 64 bits/block
    Throughput = (Rate * F) / Cycles_per_block
    """
    tp_aead = (64.0 * f_mhz) / variant["cycles_aead"]
    tp_hash = (64.0 * f_mhz) / variant["cycles_hash"]
    return tp_aead, tp_hash

def main():
    PERF_DIR.mkdir(parents=True, exist_ok=True)
    table_path = PERF_DIR / "comparison_table.md"
    
    results = []
    
    print("================================================================================")
    print("ASCON PERMUTATION VARIANTS SYNTHESIS & PERFORMANCE EVALUATION")
    print("Target Device: AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Zybo Z7-10)")
    print("Constraint   : 100.000 MHz (10.000 ns clock period)")
    print("================================================================================\n")
    
    for v in VARIANTS:
        util_path = SYNTH_DIR / f"{v['id']}_util.rpt"
        timing_path = TIMING_DIR / f"{v['id']}_timing.rpt"
        
        util_data = parse_utilization(util_path)
        timing_data = parse_timing(timing_path)
        
        if util_data is None or timing_data is None:
            print(f"[-] Variant {v['id']}: Report files missing or incomplete.")
            results.append({
                "variant": v,
                "status": "MISSING",
                "util": util_data,
                "timing": timing_data
            })
            continue
        
        tp_aead_100, tp_hash_100 = compute_throughputs(v, 100.0)
        tp_aead_fmax, tp_hash_fmax = compute_throughputs(v, timing_data["f_max"])
        
        # Efficiency: Throughput (Mbit/s @ 100MHz) / Slice LUTs
        eff_aead = tp_aead_100 / util_data["luts"] if util_data["luts"] else 0.0
        eff_hash = tp_hash_100 / util_data["luts"] if util_data["luts"] else 0.0

        res_entry = {
            "variant": v,
            "status": "PASS",
            "util": util_data,
            "timing": timing_data,
            "tp_aead_100": tp_aead_100,
            "tp_hash_100": tp_hash_100,
            "tp_aead_fmax": tp_aead_fmax,
            "tp_hash_fmax": tp_hash_fmax,
            "eff_aead": eff_aead,
            "eff_hash": eff_hash
        }
        results.append(res_entry)
        
        print(f"[+] Variant: {v['name']} ({v['id']})")
        print(f"    LUTs: {util_data['luts']} | FFs: {util_data['ffs']} | BRAM: {util_data['bram']} | DSP: {util_data['dsp']}")
        print(f"    WNS @ 100MHz: {timing_data['wns']:+.3f} ns ({'MET' if timing_data['timing_met'] else 'VIOLATED'})")
        print(f"    F_max (routed): {timing_data['f_max']:.2f} MHz (T_min: {timing_data['t_min']:.3f} ns)")
        print(f"    AEAD-128 Throughput: {tp_aead_100:.2f} Mbit/s @ 100MHz | {tp_aead_fmax:.2f} Mbit/s @ Fmax")
        print(f"    Hash-256 Throughput: {tp_hash_100:.2f} Mbit/s @ 100MHz | {tp_hash_fmax:.2f} Mbit/s @ Fmax")
        print(f"    Hardware Efficiency: {eff_aead:.3f} Mbit/s/LUT (AEAD) | {eff_hash:.3f} Mbit/s/LUT (Hash)\n")

    # Generate Markdown Table
    with open(table_path, "w", encoding="utf-8") as md:
        md.write("# Ascon Hardware Architectural Variants Performance Comparison\n\n")
        md.write("**Target Device:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Digilent Zybo Z7-10)  \n")
        md.write("**Synthesis Mode:** Out-of-Context (OOC) Placement & Routing  \n")
        md.write("**Target Clock Period:** 10.000 ns (100.00 MHz)  \n")
        md.write("**Toolchain:** Vivado v2025.1 (win64)  \n\n")
        
        md.write("## 1. Resource Utilization & Maximum Timing Frequency (Permutation Cores OOC)\n\n")
        md.write("| Architecture Variant | Top Module | Slice LUTs | Slice FFs | BRAM Tile | DSP | WNS @ 100MHz (ns) | 100MHz Timing | F_max (MHz) | T_min (ns) |\n")
        md.write("| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n")
        
        for r in results:
            v = r["variant"]
            if r["status"] == "PASS":
                u = r["util"]
                t = r["timing"]
                status_str = "**MET**" if t["timing_met"] else "**VIOLATED**"
                md.write(f"| {v['name']} | `{v['id']}` | {u['luts']} | {u['ffs']} | {u['bram']} | {u['dsp']} | {t['wns']:+.3f} | {status_str} | **{t['f_max']:.2f}** | {t['t_min']:.3f} |\n")
            else:
                md.write(f"| {v['name']} | `{v['id']}` | — | — | — | — | — | — | — | — |\n")
        
        # Add Full SoC System Row
        soc_util_path = SYNTH_DIR / "utilization_bringup.txt"
        soc_timing_path = TIMING_DIR / "timing_bringup.txt"
        soc_util = parse_utilization(soc_util_path)
        soc_timing = parse_timing(soc_timing_path)
        if soc_util and soc_timing:
            soc_status = "**MET**" if soc_timing["timing_met"] else "**VIOLATED**"
            md.write(f"| **Full SoC System (PicoRV32 + Ascon Engine)** | `top_bringup_board` | **{soc_util['luts']}** | **{soc_util['ffs']}** | **{soc_util['bram']}** | **{soc_util['dsp']}** | **{soc_timing['wns']:+.3f}** | {soc_status} | **{soc_timing['f_max']:.2f}** | **{soc_timing['t_min']:.3f}** |\n")
        
        md.write("\n## 2. Cryptographic Throughput & Hardware Efficiency\n\n")
        md.write("| Architecture Variant | Cycles / AEAD Block | Cycles / Hash Block | AEAD-128 @ 100MHz (Mbit/s) | AEAD-128 @ F_max (Mbit/s) | Hash-256 @ 100MHz (Mbit/s) | Hash-256 @ F_max (Mbit/s) | AEAD Efficiency (Mbit/s/LUT) |\n")
        md.write("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n")
        
        for r in results:
            v = r["variant"]
            if r["status"] == "PASS":
                md.write(f"| {v['name']} | {v['cycles_aead']} | {v['cycles_hash']} | {r['tp_aead_100']:.2f} | **{r['tp_aead_fmax']:.2f}** | {r['tp_hash_100']:.2f} | **{r['tp_hash_fmax']:.2f}** | {r['eff_aead']:.3f} |\n")
            else:
                md.write(f"| {v['name']} | {v['cycles_aead']} | {v['cycles_hash']} | — | — | — | — | — |\n")
        
        md.write("\n## 3. Architectural Analysis & Trade-offs\n\n")
        for r in results:
            v = r["variant"]
            md.write(f"### {v['name']} (`{v['id']}`)\n")
            md.write(f"- **Implementation Strategy:** {v['desc']}\n")
            if r["status"] == "PASS":
                u = r["util"]
                t = r["timing"]
                md.write(f"- **Resource Footprint:** Consumes {u['luts']} LUTs and {u['ffs']} Flip-Flops on XC7Z010.\n")
                md.write(f"- **Timing Margin:** Worst Negative Slack is {t['wns']:+.3f} ns at 100 MHz, achieving maximum frequency $F_{{max}} = {t['f_max']:.2f}$ MHz.\n")
                md.write(f"- **Throughput Characteristics:** Delivers {r['tp_aead_100']:.2f} Mbit/s AEAD-128 throughput at 100 MHz, scaling to {r['tp_aead_fmax']:.2f} Mbit/s at peak frequency.\n\n")
        
        md.write("## 4. Verification & Audit Trail\n\n")
        md.write("- **Zero Fabrication Guarantee:** All resource counts (LUT, FF, BRAM, DSP) and timing slacks (WNS) are parsed directly from routed Vivado reports in `results/synthesis/` and `results/timing/`.\n")
        md.write("- **Report Files:**\n")
        for v in VARIANTS:
            md.write(f"  - `{v['id']}`: `results/synthesis/{v['id']}_util.rpt` and `results/timing/{v['id']}_timing.rpt`\n")
    
    print(f"[+] Successfully generated performance comparison table: {table_path}")

if __name__ == "__main__":
    main()
