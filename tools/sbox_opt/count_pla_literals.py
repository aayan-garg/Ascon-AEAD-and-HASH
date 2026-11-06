#!/usr/bin/env python3
"""
tools/sbox_opt/count_pla_literals.py
Authoritative literal and connection counter for PLA covers.

Definitions:
1. Input Literals: Non-dash characters ('0' or '1') in the PLA input plane.
   Each input literal represents a variable (or complemented variable) in an AND cube.
2. Output Connections: '1' characters in the PLA output plane.
   Each output connection represents an input to the output OR gate.
3. Total Grid Points / Cross-points: Input literals + output connections.
"""

import os
import sys
from pathlib import Path

def count_pla(pla_path: Path):
    if not pla_path.exists():
        print(f"[-] PLA file not found: {pla_path}")
        sys.exit(1)

    with open(pla_path, "r", encoding="utf-8") as f:
        raw_lines = f.readlines()

    cubes = []
    in_names = []
    out_names = []
    
    for line in raw_lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith(".ilb"):
            in_names = line.split()[1:]
            continue
        if line.startswith(".ob"):
            out_names = line.split()[1:]
            continue
        if line.startswith("."):
            continue
        parts = line.split()
        if len(parts) == 2:
            cubes.append((parts[0], parts[1]))

    num_cubes = len(cubes)
    num_inputs = len(cubes[0][0]) if cubes else 0
    num_outputs = len(cubes[0][1]) if cubes else 0

    input_literals = sum(sum(1 for c in in_p if c in ("0", "1")) for in_p, _ in cubes)
    output_connections = sum(sum(1 for c in out_p if c == "1") for _, out_p in cubes)
    total_grid = input_literals + output_connections

    print("=" * 80)
    print(f"PLA LITERAL COUNT REPORT: {pla_path.name}")
    print("=" * 80)
    print(f"Path:                {pla_path}")
    print(f"Total Product Terms: {num_cubes}")
    print(f"Inputs:              {num_inputs} ({', '.join(in_names) if in_names else 'x0..x4'})")
    print(f"Outputs:             {num_outputs} ({', '.join(out_names) if out_names else 'y0..y4'})")
    print("-" * 80)
    print(f"Definition 1: Input Literals (non-dash input plane)       : {input_literals}")
    print(f"Definition 2: Output Connections (1s in output plane)     : {output_connections}")
    print(f"Definition 3: Combined Connections (Input Lits + Output)  : {total_grid}")
    print("-" * 80)
    print("Per-Output Breakdown:")
    for out_idx in range(num_outputs):
        out_name = out_names[out_idx] if out_idx < len(out_names) else f"y{out_idx}"
        cubes_for_out = [c_in for c_in, c_out in cubes if c_out[out_idx] == "1"]
        lits_for_out = sum(sum(1 for c in c_in if c in ("0", "1")) for c_in in cubes_for_out)
        print(f"  {out_name}: {len(cubes_for_out):2d} terms, {lits_for_out:2d} input literals")
    print("=" * 80)

    return {
        "cubes": num_cubes,
        "input_literals": input_literals,
        "output_connections": output_connections,
        "total_grid": total_grid
    }

def main():
    root_dir = Path(__file__).resolve().parent.parent.parent
    default_pla = root_dir / "results" / "synthesis" / "espresso_raw_output.pla"
    pla_target = Path(sys.argv[1]) if len(sys.argv) > 1 else default_pla
    count_pla(pla_target)

if __name__ == "__main__":
    main()
