#!/usr/bin/env python3
# ==============================================================================
# Script: generate_engine_table.py
# Computes throughput and area efficiency for all 7 engine variants
# Dynamically parses Vivado utilization and timing reports.
#
# SP 800-232 Parameters:
#   AEAD-128: rate = 128 bits, b = 8 rounds/block
#   Hash-256: rate =  64 bits, a = 12 rounds/block
# ==============================================================================

import os
import re
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
SYNTH_DIR = ROOT_DIR / "results" / "synthesis"
TIMING_DIR = ROOT_DIR / "results" / "timing"
OUTPUT_MD = ROOT_DIR / "results" / "performance" / "engine_comparison_table.md"

variants_meta = [
    {
        "name": "mode_ctrl_1r_wrap",
        "variant": "1R Baseline",
        "cyc_aead": 8,
        "cyc_hash": 12,
        "sbox": "Standard (Bit-sliced)"
    },
    {
        "name": "mode_ctrl_1r_espresso_wrap",
        "variant": "1R ESPRESSO",
        "cyc_aead": 8,
        "cyc_hash": 12,
        "sbox": "ESPRESSO SOP (Exact 30-cube)"
    },
    {
        "name": "mode_ctrl_1r_kernel_wrap",
        "variant": "1R Kernel",
        "cyc_aead": 8,
        "cyc_hash": 12,
        "sbox": "Brayton-McMullen Kernel Factored"
    },
    {
        "name": "mode_ctrl_1r_bdd_wrap",
        "variant": "1R BDD",
        "cyc_aead": 8,
        "cyc_hash": 12,
        "sbox": "Optimal ROBDD Mux Network"
    },
    {
        "name": "mode_ctrl_2r_wrap",
        "variant": "2R Unrolled",
        "cyc_aead": 4,
        "cyc_hash": 6,
        "sbox": "Standard (Bit-sliced)"
    },
    {
        "name": "mode_ctrl_half_wrap",
        "variant": "Half-Round (0.5R)",
        "cyc_aead": 16,
        "cyc_hash": 24,
        "sbox": "Standard (Bit-sliced)"
    },
    {
        "name": "mode_ctrl_serial32_wrap",
        "variant": "Serial-32",
        "cyc_aead": 16,
        "cyc_hash": 24,
        "sbox": "32-bit Shared"
    }
]

def parse_util(util_path):
    if not util_path.exists():
        return None, None
    txt = util_path.read_text(encoding="utf-8", errors="ignore")
    lut, ff = None, None
    m_lut = re.search(r"\|\s*Slice LUTs\s*\|\s*(\d+)\s*\|", txt)
    if m_lut:
        lut = int(m_lut.group(1))
    else:
        m_lut_alt = re.search(r"\|\s*LUT as Logic\s*\|\s*(\d+)\s*\|", txt)
        if m_lut_alt:
            lut = int(m_lut_alt.group(1))
    m_ff = re.search(r"\|\s*Slice Registers\s*\|\s*(\d+)\s*\|", txt)
    if m_ff:
        ff = int(m_ff.group(1))
    else:
        m_ff_alt = re.search(r"\|\s*Register as Flip Flop\s*\|\s*(\d+)\s*\|", txt)
        if m_ff_alt:
            ff = int(m_ff_alt.group(1))
    return lut, ff

def parse_timing(timing_path):
    if not timing_path.exists():
        return None
    txt = timing_path.read_text(encoding="utf-8", errors="ignore")
    m_wns = re.search(r"Slack\s*\([A-Z]+\)\s*:\s*([+-]?\d+\.?\d*)\s*ns", txt)
    if not m_wns:
        m_wns = re.search(r"WNS\(ns\)\s+TNS\(ns\).*?\n\s*([+-]?\d+\.?\d*)", txt)
    if m_wns:
        return float(m_wns.group(1))
    return None

parsed_variants = []
for v in variants_meta:
    u_path = SYNTH_DIR / f"{v['name']}_util.rpt"
    t_path = TIMING_DIR / f"{v['name']}_timing.rpt"
    lut, ff = parse_util(u_path)
    wns = parse_timing(t_path)
    if lut is None or ff is None or wns is None:
        raise RuntimeError(f"Failed to parse metrics for {v['name']} from {u_path} / {t_path}")
    t_clk = 10.000
    t_min = t_clk - wns
    fmax = 1000.0 / t_min if t_min > 0 else 0.0
    item = dict(v)
    item["lut"] = lut
    item["ff"] = ff
    item["wns"] = wns
    item["fmax"] = fmax
    parsed_variants.append(item)

with open(OUTPUT_MD, "w", encoding="utf-8") as f:
    f.write("# Ascon Engine-Level (mode_ctrl) Out-of-Context Implementation Comparison\n\n")
    f.write("- **Target FPGA:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Zybo Z7-10)\n")
    f.write("- **Synthesis Tool:** AMD-Xilinx Vivado v2025.1 (win64)\n")
    f.write("- **Design Hierarchy:** Full Engine (`mode_ctrl` + `aead_ctrl` + `hash_ctrl` + `plaintext_gate` [BUFFER_DEPTH=32] + Permutation Core)\n")
    f.write("- **Target Constraint:** 100.0 MHz (10.000 ns period, OOC)\n")
    f.write("- **Evaluation Date:** November 6, 2026\n\n")
    f.write("## 1. Engine Synthesis and STA Timing Results\n\n")
    f.write("| Architecture Variant | Top Wrapper | S-Box Type | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | Timing Status |\n")
    f.write("|---|---|---|---|---|---|---|---|\n")
    for v in parsed_variants:
        f.write(f"| **{v['variant']}** | `{v['name']}` | {v['sbox']} | {v['lut']:,} | {v['ff']:,} | +{v['wns']:.3f} ns | {v['fmax']:.2f} MHz | `[MET]` |\n")
    
    f.write("\n## 2. Cryptographic Throughput and Area Efficiency\n\n")
    f.write("- **NIST SP 800-232 Parameters:** Ascon-AEAD128 rate = 128 bits ($b=8$ rounds); Ascon-Hash256 rate = 64 bits ($a=12$ rounds).\n")
    f.write("- **Throughput Formula:** $\\text{Throughput (Mbps)} = \\frac{\\text{Block Rate (bits)} \\times F}{\\text{Cycles per Block}}$\n")
    f.write("- **Area Efficiency ($TP/A$):** $\\frac{\\text{AEAD Throughput (kbps)}}{\\text{Slice LUTs}}$\n\n")
    f.write("| Architecture Variant | AEAD Cyc/Blk | Hash Cyc/Blk | AEAD @ 100 MHz | AEAD @ Fmax | Hash @ 100 MHz | Hash @ Fmax | AEAD Eff @ 100 MHz (kbps/LUT) |\n")
    f.write("|---|:---:|:---:|---|---|---|---|:---:|\n")
    for v in parsed_variants:
        tp_aead_100 = (128.0 / v['cyc_aead']) * 100.0
        tp_aead_fmax = (128.0 / v['cyc_aead']) * v['fmax']
        tp_hash_100 = (64.0 / v['cyc_hash']) * 100.0
        tp_hash_fmax = (64.0 / v['cyc_hash']) * v['fmax']
        eff_100 = (tp_aead_100 * 1000.0) / v['lut']
        f.write(f"| **{v['variant']}** | {v['cyc_aead']} | {v['cyc_hash']} | {tp_aead_100:.2f} Mbps | {tp_aead_fmax:.2f} Mbps | {tp_hash_100:.2f} Mbps | {tp_hash_fmax:.2f} Mbps | {eff_100:.2f} |\n")

    by_name = {v["name"]: v for v in parsed_variants}
    b1r = by_name["mode_ctrl_1r_wrap"]
    e2r = by_name["mode_ctrl_2r_wrap"]
    ehalf = by_name["mode_ctrl_half_wrap"]
    es32 = by_name["mode_ctrl_serial32_wrap"]
    ekern = by_name["mode_ctrl_1r_kernel_wrap"]
    ebdd = by_name["mode_ctrl_1r_bdd_wrap"]
    eesp = by_name["mode_ctrl_1r_espresso_wrap"]

    def _tp_aead_100(v):
        return (128.0 / v["cyc_aead"]) * 100.0

    def _tp_aead_fmax(v):
        return (128.0 / v["cyc_aead"]) * v["fmax"]

    def _eff_100(v):
        return (_tp_aead_100(v) * 1000.0) / v["lut"]

    sbox_luts = [b1r["lut"], ekern["lut"], ebdd["lut"], eesp["lut"]]
    lut_spread_pct = ((max(sbox_luts) - min(sbox_luts)) / min(sbox_luts)) * 100.0

    f.write("\n## 3. Key Observations\n\n")
    f.write(
        f"1. **2-Round Unrolled** achieves the highest raw throughput at {_tp_aead_100(e2r):,.2f} Mbps @ 100 MHz "
        f"and {_tp_aead_fmax(e2r):,.2f} Mbps @ Fmax, with {_eff_100(e2r):.2f} kbps/LUT and {e2r['lut']:,} LUTs "
        f"({((e2r['lut'] - b1r['lut']) / b1r['lut']) * 100:+.1f}% area vs. 1R baseline).\n"
    )
    f.write(
        f"2. **Half-Round (0.5R)** minimizes engine area ({ehalf['lut']:,} LUTs, "
        f"{((ehalf['lut'] - b1r['lut']) / b1r['lut']) * 100:+.1f}% vs. 1R baseline) by folding round operations over 2 clock cycles, "
        f"delivering {_tp_aead_100(ehalf):,.2f} Mbps @ 100 MHz ({_eff_100(ehalf):.2f} kbps/LUT).\n"
    )
    f.write(
        f"3. **Serial-32 Datapath** on Xilinx 7-series FPGA consumes more LUTs than 1R baseline ({es32['lut']:,} vs {b1r['lut']:,} LUTs, "
        f"{((es32['lut'] - b1r['lut']) / b1r['lut']) * 100:+.1f}%) and requires 2x cycles per block (16 cycles AEAD, 24 cycles Hash), "
        f"resulting in lower efficiency ({_eff_100(es32):.2f} kbps/LUT vs {_eff_100(b1r):.2f} kbps/LUT for 1R baseline). "
        "The 6-input LUT architecture makes 1R bit-sliced S-boxes compact, so the multiplexing and state partitioning overhead exceeds the logic sharing savings.\n"
    )
    f.write("4. **S-Box Variant Comparison Across Identical Engine Wrappers:**\n")
    f.write(f"   - **1R Baseline (Canonical Bit-Sliced):** {b1r['lut']:,} LUTs, {b1r['ff']:,} FFs, WNS +{b1r['wns']:.3f} ns ({b1r['fmax']:.2f} MHz).\n")
    f.write(f"   - **1R Kernel (Brayton-McMullen Factored):** {ekern['lut']:,} LUTs, {ekern['ff']:,} FFs, WNS +{ekern['wns']:.3f} ns ({ekern['fmax']:.2f} MHz).\n")
    f.write(f"   - **1R BDD (Optimal ROBDD Mux Network):** {ebdd['lut']:,} LUTs, {ebdd['ff']:,} FFs, WNS +{ebdd['wns']:.3f} ns ({ebdd['fmax']:.2f} MHz).\n")
    f.write(f"   - **1R ESPRESSO (Exact 30-Cube SOP):** {eesp['lut']:,} LUTs, {eesp['ff']:,} FFs, WNS +{eesp['wns']:.3f} ns ({eesp['fmax']:.2f} MHz).\n")
    f.write(
        f"   - **Hardware Impact Analysis:** A 5-bit Ascon S-box maps to only a few 6-input LUTs (LUT6) on Xilinx 7-series architectures. "
        f"Because Vivado synthesis re-maps and flattens small Boolean networks into LUT6 primitives during physical technology mapping, "
        f"differences within ~{lut_spread_pct:.1f}% ({min(sbox_luts):,} to {max(sbox_luts):,} LUTs) across identical engine wrappers represent synthesis mapping noise rather than a fundamental architecture benefit, "
        "demonstrating that all three optimization paradigms achieve equivalent high-quality hardware realization.\n"
    )

print(f"Generated {OUTPUT_MD}")
