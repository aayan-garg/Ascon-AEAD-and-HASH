#!/usr/bin/env python3
"""
tools/sbox_opt/bdd_synthesizer.py
Binary Decision Diagram (BDD) Decomposition and Synthesis for Ascon 5x5 S-Box.
Builds Reduced Ordered Binary Decision Diagrams (ROBDDs), analyzes variable ordering,
computes node counts, and synthesizes SystemVerilog 2:1 multiplexer (ITE) networks.
"""

import os
import sys

NIST_TABLE = [
    0x04, 0x0b, 0x1f, 0x14, 0x1a, 0x15, 0x09, 0x02,
    0x1b, 0x05, 0x08, 0x12, 0x1d, 0x03, 0x06, 0x1c,
    0x1e, 0x13, 0x07, 0x0e, 0x00, 0x0d, 0x11, 0x18,
    0x10, 0x0c, 0x01, 0x19, 0x16, 0x0a, 0x0f, 0x17
]

class BDDNode:
    def __init__(self, var, low, high, id_num):
        self.var = var       # variable index (0 to 4 corresponding to x0..x4)
        self.low = low       # low branch (when var == 0): node_id or terminal 0/1
        self.high = high     # high branch (when var == 1): node_id or terminal 0/1
        self.id = id_num

    def __repr__(self):
        return f"Node_{self.id}(x{self.var}, L={self.low}, H={self.high})"

def build_robdd(tt_dict, order, shared_unique=None, shared_nodes=None, start_id=2):
    """
    Constructs a Reduced Ordered Binary Decision Diagram (ROBDD).
    Reduction rules applied:
      1. Terminal reduction: isomorphic leaves merged to 0 or 1.
      2. Redundant test elimination: if low == high, node is skipped.
      3. Isomorphic subgraph sharing: identical (var, low, high) share the same node ID.
    """
    unique_table = shared_unique if shared_unique is not None else {}
    nodes = shared_nodes if shared_nodes is not None else {}
    next_id = start_id if shared_unique is None else (max(nodes.keys(), default=1) + 1)

    def get_node(var_idx, sub_tt):
        nonlocal next_id
        vals = set(sub_tt.values())
        if len(vals) == 1:
            return list(vals)[0] # Terminal 0 or 1
        
        var = order[var_idx]
        low_tt = {k: v for k, v in sub_tt.items() if k[var] == 0}
        high_tt = {k: v for k, v in sub_tt.items() if k[var] == 1}
        
        low_id = get_node(var_idx + 1, low_tt)
        high_id = get_node(var_idx + 1, high_tt)
        
        # ROBDD Reduction Rule 1: Eliminate redundant test
        if low_id == high_id:
            return low_id
        
        # ROBDD Reduction Rule 2: Share isomorphic nodes
        key = (var, low_id, high_id)
        if key in unique_table:
            return unique_table[key]
        
        n_id = next_id
        next_id += 1
        unique_table[key] = n_id
        nodes[n_id] = BDDNode(var, low_id, high_id, n_id)
        return n_id

    root = get_node(0, tt_dict)
    return root, nodes, unique_table

def analyze_orderings():
    print("================================================================================")
    print("ASCON 5x5 S-BOX: BDD VARIABLE ORDERING SENSITIVITY STUDY")
    print("================================================================================")
    
    orderings = [
        ("Natural Order [x0, x1, x2, x3, x4]", [0, 1, 2, 3, 4]),
        ("Reversed Order [x4, x3, x2, x1, x0]", [4, 3, 2, 1, 0]),
        ("Interleaved [x1, x3, x0, x2, x4]", [1, 3, 0, 2, 4]),
        ("Optimized [x2, x1, x3, x0, x4]", [2, 1, 3, 0, 4])
    ]

    results = []

    for name, order in orderings:
        print(f"\nEvaluating Order: {name}")
        per_output_nodes = {}
        shared_unique = {}
        shared_nodes = {}
        roots = []
        
        for bit in range(5):
            tt = {}
            for idx, val in enumerate(NIST_TABLE):
                in_tuple = tuple((idx >> (4 - j)) & 1 for j in range(5))
                tt[in_tuple] = (val >> (4 - bit)) & 1
            
            # Independent BDD
            r_indep, nodes_indep, _ = build_robdd(tt, order)
            per_output_nodes[f"y{bit}"] = len(nodes_indep)
            
            # Shared multi-rooted BDD
            r_shared, _, _ = build_robdd(tt, order, shared_unique, shared_nodes)
            roots.append(r_shared)

        unshared_total = sum(per_output_nodes.values())
        shared_total = len(shared_nodes)
        print(f"  Independent Node Counts: {per_output_nodes} (Sum = {unshared_total})")
        print(f"  Multi-Rooted Shared BDD Total Nodes: {shared_total} (Sharing savings: {unshared_total - shared_total} nodes)")
        results.append((name, order, per_output_nodes, unshared_total, shared_total, roots, shared_nodes))

    return results

def generate_verilog_bdd(order_name, order, roots, nodes, output_path):
    """Generates pure SystemVerilog 2:1 multiplexer network from the shared ROBDD."""
    lines = [
        "// ==============================================================================",
        "// Module: sbox5_bdd.sv",
        "// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)",
        "// Description: 5-bit Ascon S-box synthesized from Reduced Ordered Binary Decision",
        f"//              Diagrams (ROBDD) with Variable Ordering: {order_name}.",
        f"// Complexity: {len(nodes)} 2:1 Multiplexer (ITE) nodes.",
        "// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6.",
        "// ==============================================================================",
        "",
        "`timescale 1ns / 1ps",
        "`default_nettype wire",
        "",
        "module sbox5_bdd (",
        "    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4} (x0 is MSB, x4 is LSB)",
        "    output wire [4:0] out_y  // {y0, y1, y2, y3, y4} (y0 is MSB, y4 is LSB)",
        ");",
        "",
        "    wire x0 = in_x[4];",
        "    wire x1 = in_x[3];",
        "    wire x2 = in_x[2];",
        "    wire x3 = in_x[1];",
        "    wire x4 = in_x[0];",
        "",
        "    wire [4:0] x_bus = {x0, x1, x2, x3, x4};",
        "",
        "    // Constant Terminals",
        "    wire term_0 = 1'b0;",
        "    wire term_1 = 1'b1;",
        "",
        f"    // Shared ROBDD Multiplexer Network ({len(nodes)} ITE nodes):"
    ]

    # Sort nodes by ID ascending
    sorted_node_ids = sorted(nodes.keys())
    for nid in sorted_node_ids:
        node = nodes[nid]
        v_name = f"x{node.var}"
        
        def format_branch(target):
            if target == 0:
                return "term_0"
            elif target == 1:
                return "term_1"
            else:
                return f"node_{target}"

        low_str = format_branch(node.low)
        high_str = format_branch(node.high)
        lines.append(f"    wire node_{nid} = {v_name} ? {high_str} : {low_str};")

    lines.append("")
    lines.append("    // Multi-Root Output Mapping:")
    for bit in range(5):
        root_id = roots[bit]
        if root_id == 0:
            lines.append(f"    wire y{bit} = term_0;")
        elif root_id == 1:
            lines.append(f"    wire y{bit} = term_1;")
        else:
            lines.append(f"    wire y{bit} = node_{root_id};")

    lines.append("")
    lines.append("    assign out_y = {y0, y1, y2, y3, y4};")
    lines.append("")
    lines.append("endmodule")
    lines.append("")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[+] Emitted BDD Verilog module: {output_path}")

def main():
    results = analyze_orderings()
    best = min(results, key=lambda x: x[4]) # Best shared node count
    best_name, best_order, _, _, shared_total, roots, shared_nodes = best
    
    print("\n--------------------------------------------------------------------------------")
    print(f"Optimal Ordering: {best_name} with {shared_total} shared BDD nodes.")
    print("--------------------------------------------------------------------------------")

    # Generate RTL
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    rtl_path = os.path.join(repo_root, "rtl/ascon/sbox5_bdd.sv")
    generate_verilog_bdd(best_name, best_order, roots, shared_nodes, rtl_path)

    # Exhaustive verification
    print("\nVerifying synthesized BDD against NIST Table 6 across all 32 inputs...")
    mismatches = 0
    for idx in range(32):
        in_bits = [(idx >> (4 - j)) & 1 for j in range(5)]
        # Evaluate node network
        node_vals = {0: 0, 1: 1}
        for nid in sorted(shared_nodes.keys()):
            n = shared_nodes[nid]
            v = in_bits[n.var]
            node_vals[nid] = node_vals[n.high] if v else node_vals[n.low]
        
        computed_y = 0
        for bit in range(5):
            r = roots[bit]
            val = node_vals[r]
            if val:
                computed_y |= (1 << (4 - bit))
        
        expected_y = NIST_TABLE[idx]
        if computed_y != expected_y:
            print(f"[-] MISMATCH at 0x{idx:02X}: computed=0x{computed_y:02X}, expected=0x{expected_y:02X}")
            mismatches += 1

    if mismatches == 0:
        print("[SUCCESS] 100% equivalence verified (32/32 vectors bit-exact match).")
    else:
        print(f"[FAIL] {mismatches} mismatches detected!")
        sys.exit(1)

if __name__ == "__main__":
    main()

