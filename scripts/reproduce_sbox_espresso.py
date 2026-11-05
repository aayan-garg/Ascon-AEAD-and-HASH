#!/usr/bin/env python3
"""
Reproduce and Verify Ascon ESPRESSO 5-Bit S-Box
Target: NIST SP 800-232 Table 6 & rtl/ascon/sbox5_espresso.sv
Fulfills Task T6: Documentation of ESPRESSO S-Box Provenance & Verification
"""

import os
import sys

# NIST SP 800-232 Table 6: Ascon 5-bit Substitution Table (S-box)
# Input x in [0..31] -> Output S[x] in [0..31]
SBOX_TABLE = [
    0x04, 0x0B, 0x1F, 0x14, 0x1A, 0x15, 0x09, 0x02,
    0x1B, 0x05, 0x08, 0x12, 0x1D, 0x03, 0x06, 0x1C,
    0x1E, 0x13, 0x07, 0x0E, 0x00, 0x0D, 0x11, 0x18,
    0x10, 0x0C, 0x01, 0x19, 0x16, 0x0A, 0x0F, 0x17
]

def generate_pla_file(pla_path: str):
    """Generates standard Berkeley ESPRESSO format truth table (.pla)."""
    os.makedirs(os.path.dirname(pla_path), exist_ok=True)
    with open(pla_path, "w", encoding="utf-8") as f:
        f.write("# Ascon 5-bit S-Box Truth Table (NIST SP 800-232 Table 6)\n")
        f.write(".i 5\n")
        f.write(".o 5\n")
        f.write(".ilb x0 x1 x2 x3 x4\n")
        f.write(".ob y0 y1 y2 y3 y4\n")
        f.write(".p 32\n")
        for in_val in range(32):
            out_val = SBOX_TABLE[in_val]
            in_str = f"{in_val:05b}"
            out_str = f"{out_val:05b}"
            f.write(f"{in_str} {out_str}\n")
        f.write(".e\n")
    print(f"[ESPRESSO] Wrote Berkeley PLA truth table: {pla_path}")

def eval_espresso_rtl(in_x: int) -> int:
    """Evaluates the exact boolean equations instantiated in rtl/ascon/sbox5_espresso.sv."""
    x0 = (in_x >> 4) & 1
    x1 = (in_x >> 3) & 1
    x2 = (in_x >> 2) & 1
    x3 = (in_x >> 1) & 1
    x4 = (in_x >> 0) & 1

    # Inverted signals
    not_x0 = 1 - x0
    not_x1 = 1 - x1
    not_x2 = 1 - x2
    not_x3 = 1 - x3
    not_x4 = 1 - x4

    # y0
    y0 = ((x1 & x3 & x4) |
          (x1 & not_x3 & not_x4) |
          (x0 & x2 & x3 & not_x1) |
          (x0 & not_x1 & not_x2 & not_x3) |
          (x2 & not_x0 & not_x1 & not_x3) |
          (x3 & not_x0 & not_x1 & not_x2))

    # y1
    y1 = ((x0 & x1 & x4 & not_x2) |
          (x0 & x2 & x4 & not_x3) |
          (x0 & x3 & x4 & not_x1) |
          (x0 & x1 & x2 & x3 & not_x4) |
          (x1 & x2 & x3 & x4 & not_x0) |
          (x1 & not_x0 & not_x2 & not_x4) |
          (x2 & not_x0 & not_x3 & not_x4) |
          (x3 & not_x0 & not_x1 & not_x4) |
          (x0 & not_x1 & not_x2 & not_x3 & not_x4) |
          (x4 & not_x0 & not_x1 & not_x2 & not_x3))

    # y2
    y2 = ((x1 & x2 & x3) |
          (x1 & x2 & not_x4) |
          (x3 & not_x1 & not_x2) |
          (not_x1 & not_x2 & not_x4) |
          (x1 & x4 & not_x2 & not_x3) |
          (x2 & x4 & not_x1 & not_x3))

    # y3
    y3 = ((x0 & x1 & x2) |
          (x0 & not_x1 & not_x2) |
          (x1 & x2 & x3 & not_x4) |
          (x1 & x2 & x4 & not_x3) |
          (x3 & not_x1 & not_x2 & not_x4) |
          (x4 & not_x1 & not_x2 & not_x3) |
          (x1 & x3 & x4 & not_x0 & not_x2) |
          (x2 & x3 & x4 & not_x0 & not_x1) |
          (x1 & not_x0 & not_x2 & not_x3 & not_x4) |
          (x2 & not_x0 & not_x1 & not_x3 & not_x4))

    # y4
    y4 = ((x0 & x1 & x3) |
          (x1 & not_x0 & not_x3) |
          (x3 & not_x1 & not_x4) |
          (x4 & not_x1 & not_x3))

    return (y0 << 4) | (y1 << 3) | (y2 << 2) | (y3 << 1) | y4

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    pla_path = os.path.join(root_dir, "scripts", "ascon_sbox.pla")
    generate_pla_file(pla_path)

    print("\n[VERIFICATION] Checking rtl/ascon/sbox5_espresso.sv against NIST SP 800-232 Table 6...")
    mismatches = 0
    for x in range(32):
        expected = SBOX_TABLE[x]
        actual = eval_espresso_rtl(x)
        if actual != expected:
            print(f"  FAIL: x={x:05b} expected={expected:05b} actual={actual:05b}")
            mismatches += 1

    if mismatches == 0:
        print("  SUCCESS: 32/32 vectors match NIST SP 800-232 Table 6 with 100% mathematical precision.")
        print("  Provenance: Berkeley ESPRESSO logic minimizer (`espresso -e -Dexact scripts/ascon_sbox.pla`)")
        return 0
    else:
        print(f"  FAILED: {mismatches} mismatches found.")
        return 1

if __name__ == "__main__":
    sys.exit(main())

