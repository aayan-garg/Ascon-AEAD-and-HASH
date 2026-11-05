#!/usr/bin/env python3
"""
Convert the existing sbox5_espresso.sv equations to PLA format and verify
against NIST SP 800-232 Table 6. This script does not run ESPRESSO.
"""

import os

SBOX_TABLE = [
    0x04, 0x0B, 0x1F, 0x14, 0x1A, 0x15, 0x09, 0x02,
    0x1B, 0x05, 0x08, 0x12, 0x1D, 0x03, 0x06, 0x1C,
    0x1E, 0x13, 0x07, 0x0E, 0x00, 0x0D, 0x11, 0x18,
    0x10, 0x0C, 0x01, 0x19, 0x16, 0x0A, 0x0F, 0x17
]

eqs = {
    'y0': [
        'x1 & x3 & x4',
        'x1 & ~x3 & ~x4',
        'x0 & x2 & x3 & ~x1',
        'x0 & ~x1 & ~x2 & ~x3',
        'x2 & ~x0 & ~x1 & ~x3',
        'x3 & ~x0 & ~x1 & ~x2'
    ],
    'y1': [
        'x0 & x1 & x4 & ~x2',
        'x0 & x2 & x4 & ~x3',
        'x0 & x3 & x4 & ~x1',
        'x0 & x1 & x2 & x3 & ~x4',
        'x1 & x2 & x3 & x4 & ~x0',
        'x1 & ~x0 & ~x2 & ~x4',
        'x2 & ~x0 & ~x3 & ~x4',
        'x3 & ~x0 & ~x1 & ~x4',
        'x0 & ~x1 & ~x2 & ~x3 & ~x4',
        'x4 & ~x0 & ~x1 & ~x2 & ~x3'
    ],
    'y2': [
        'x1 & x2 & x3',
        'x1 & x2 & ~x4',
        'x3 & ~x1 & ~x2',
        '~x1 & ~x2 & ~x4',
        'x1 & x4 & ~x2 & ~x3',
        'x2 & x4 & ~x1 & ~x3'
    ],
    'y3': [
        'x0 & x1 & x2',
        'x0 & ~x1 & ~x2',
        'x1 & x2 & x3 & ~x4',
        'x1 & x2 & x4 & ~x3',
        'x3 & ~x1 & ~x2 & ~x4',
        'x4 & ~x1 & ~x2 & ~x3',
        'x1 & x3 & x4 & ~x0 & ~x2',
        'x2 & x3 & x4 & ~x0 & ~x1',
        'x1 & ~x0 & ~x2 & ~x3 & ~x4',
        'x2 & ~x0 & ~x1 & ~x3 & ~x4'
    ],
    'y4': [
        'x0 & x1 & x3',
        'x1 & ~x0 & ~x3',
        'x3 & ~x1 & ~x4',
        'x4 & ~x1 & ~x3'
    ]
}

def term_to_cube(term_str):
    cube = ['-'] * 5
    parts = [p.strip() for p in term_str.split('&')]
    for p in parts:
        inv = p.startswith('~')
        var = p[1:] if inv else p
        idx = int(var[1])
        cube[idx] = '0' if inv else '1'
    return ''.join(cube)

terms = []
out_names = ['y0', 'y1', 'y2', 'y3', 'y4']
for out_idx, out_name in enumerate(out_names):
    for term in eqs[out_name]:
        cube = term_to_cube(term)
        out_col = ['0'] * 5
        out_col[out_idx] = '1'
        terms.append((cube, ''.join(out_col)))

root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
out_pla_path = os.path.join(root_dir, 'results', 'synthesis',
                            'sbox5_espresso_rtl_as_pla.pla')
os.makedirs(os.path.dirname(out_pla_path), exist_ok=True)
with open(out_pla_path, 'w', encoding='utf-8') as f:
    f.write('# PLA conversion of rtl/ascon/sbox5_espresso.sv (NOT produced by running ESPRESSO)\n')
    f.write('# Function: Ascon 5-bit S-Box (NIST SP 800-232 Table 6)\n')
    f.write('# Source: equations in rtl/ascon/sbox5_espresso.sv\n')
    f.write(f'.i 5\n.o 5\n.ilb x0 x1 x2 x3 x4\n.ob y0 y1 y2 y3 y4\n.p {len(terms)}\n')
    for cube, out_pat in terms:
        f.write(f'{cube} {out_pat}\n')
    f.write('.e\n')

# Verify against NIST Table 6
def eval_pla(in_val):
    b = f'{in_val:05b}'
    out_bits = [0] * 5
    for cube, out_pat in terms:
        match = True
        for i in range(5):
            if cube[i] != '-' and cube[i] != b[i]:
                match = False
                break
        if match:
            for j in range(5):
                if out_pat[j] == '1':
                    out_bits[j] = 1
    res = 0
    for j in range(5):
        res = (res << 1) | out_bits[j]
    return res

mismatches = 0
for x in range(32):
    expected = SBOX_TABLE[x]
    actual = eval_pla(x)
    if actual != expected:
        print(f'Mismatch at {x:05b}: exp={expected:05b} got={actual:05b}')
        mismatches += 1

if mismatches == 0:
    print(f'[SUCCESS] Verified {out_pla_path}: 32/32 vectors match NIST SP 800-232 Table 6 with 100% precision.')
else:
    print(f'[ERROR] {mismatches} mismatches found.')
    exit(1)
