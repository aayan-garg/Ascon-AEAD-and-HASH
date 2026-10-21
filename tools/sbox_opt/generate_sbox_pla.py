#!/usr/bin/env python3
"""
Generate ESPRESSO PLA file for the Ascon 5x5 S-box.
Source: NIST SP 800-232 Table 6 & IACR ePrint 2016/198.
"""

def sbox(val):
    """
    Standard Ascon S-box bit-slice computation.
    val: 5-bit integer, where bit 4 is x0, bit 0 is x4.
    """
    x0 = (val >> 4) & 1
    x1 = (val >> 3) & 1
    x2 = (val >> 2) & 1
    x3 = (val >> 1) & 1
    x4 = (val >> 0) & 1

    # 1. Affine in
    x0 ^= x4
    x4 ^= x3
    x2 ^= x1

    # 2. Keccak chi
    t0 = x0 ^ ((~x1 & 1) & x2)
    t1 = x1 ^ ((~x2 & 1) & x3)
    t2 = x2 ^ ((~x3 & 1) & x4)
    t3 = x3 ^ ((~x4 & 1) & x0)
    t4 = x4 ^ ((~x0 & 1) & x1)

    # 3. Affine out
    t1 ^= t0
    t0 ^= t4
    t3 ^= t2
    t2 = (~t2) & 1

    return (t0 << 4) | (t1 << 3) | (t2 << 2) | (t3 << 1) | t4

# Reference lookup table from NIST SP 800-232 Table 6
NIST_TABLE = [
    0x04, 0x0b, 0x1f, 0x14, 0x1a, 0x15, 0x09, 0x02,
    0x1b, 0x05, 0x08, 0x12, 0x1d, 0x03, 0x06, 0x1c,
    0x1e, 0x13, 0x07, 0x0e, 0x00, 0x0d, 0x11, 0x18,
    0x10, 0x0c, 0x01, 0x19, 0x16, 0x0a, 0x0f, 0x17
]

def main():
    print("[*] Verifying S-box equations against NIST SP 800-232 Table 6...")
    mismatches = 0
    for i in range(32):
        computed = sbox(i)
        expected = NIST_TABLE[i]
        if computed != expected:
            print(f"[-] Mismatch at index 0x{i:02x}: computed=0x{computed:02x}, expected=0x{expected:02x}")
            mismatches += 1
    if mismatches == 0:
        print("[+] 100% equivalence verified (32/32 vectors match).")
    else:
        raise ValueError(f"S-box failed validation with {mismatches} mismatches!")

    # Write ESPRESSO PLA format
    pla_content = [
        "# ESPRESSO PLA for Ascon 5x5 S-box",
        "# Source: NIST SP 800-232 Table 6",
        ".i 5",
        ".o 5",
        ".ilb x0 x1 x2 x3 x4",
        ".ob y0 y1 y2 y3 y4",
        ".p 32"
    ]

    for i in range(32):
        out_val = sbox(i)
        in_bin = f"{i:05b}"
        out_bin = f"{out_val:05b}"
        pla_content.append(f"{in_bin} {out_bin}")

    pla_content.append(".e\n")
    
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    pla_path = os.path.join(script_dir, "ascon_sbox.pla")
    with open(pla_path, "w") as f:
        f.write("\n".join(pla_content))
    print(f"[+] Successfully wrote PLA file: {pla_path}")

if __name__ == "__main__":
    main()
