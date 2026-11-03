#!/usr/bin/env python3
"""
Automated Regression Test Runner for Ascon AEAD/Hash RTL Project
Phase 1: Automated Regression Harness

Discovers and executes:
  1. Reference Golden Model Official NIST KATs (reference/run_kats.py)
  2. Formal Verification CTL Model Checking (formal/ctl/verify_smv.py)
  3. SystemVerilog Unit Testbenches in tb/unit/ (via Vivado XSim)

Usage:
  python scripts/run_regression.py [--skip-kats] [--skip-formal] [--skip-sim]
"""

import sys
import os
import subprocess
import time
import shutil
import argparse
import platform

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SIM_BUILD_DIR = os.path.join(ROOT_DIR, "sim_build")

# ──────────────────────────────────────────────────────────────────────────────
# [F9 fix] Cross-platform Vivado detection
# Set VIVADO_PATH env var to override automatic detection, e.g.:
#   Windows: set VIVADO_PATH=C:\Xilinx\Vivado\2025.1\bin
#   Linux:   export VIVADO_PATH=/opt/Xilinx/Vivado/2025.1/bin
# ──────────────────────────────────────────────────────────────────────────────
IS_WINDOWS = platform.system() == "Windows"
EXE_SUFFIX = ".bat" if IS_WINDOWS else ""

def _find_vivado() -> str:
    """Return Vivado bin directory or None if not found."""
    # 1. VIVADO_PATH environment variable
    env_path = os.environ.get("VIVADO_PATH", "")
    if env_path:
        xvlog_name = f"xvlog{EXE_SUFFIX}"
        if os.path.exists(os.path.join(env_path, xvlog_name)):
            return env_path

    # 2. Common installation paths
    if IS_WINDOWS:
        candidates = [
            r"C:\Xilinx\Vivado\2025.1\bin",
            r"C:\Xilinx\2025.1\Vivado\bin",
            r"C:\Xilinx\Vivado\2024.2\bin",
            r"C:\Xilinx\Vivado\2024.1\bin",
            r"C:\Xilinx\Vivado\2023.2\bin",
        ]
    else:
        candidates = [
            "/opt/Xilinx/Vivado/2025.1/bin",
            "/opt/Xilinx/Vivado/2024.2/bin",
            "/tools/Xilinx/Vivado/2025.1/bin",
            "/opt/AMD/Vivado/2025.1/bin",
        ]
    for p in candidates:
        if os.path.exists(os.path.join(p, f"xvlog{EXE_SUFFIX}")):
            return p

    # 3. PATH search (xvlog without .bat suffix works on Linux)
    for name in [f"xvlog{EXE_SUFFIX}", "xvlog"]:
        found = shutil.which(name)
        if found:
            return os.path.dirname(found)

    return None

_VIVADO_BIN = _find_vivado()
if _VIVADO_BIN is None:
    print("[WARNING] Vivado not found. Set VIVADO_PATH env var to Vivado bin directory.")
    print(f"          Example (Windows): set VIVADO_PATH=C:\\Xilinx\\Vivado\\2025.1\\bin")
    print(f"          Example (Linux):   export VIVADO_PATH=/opt/Xilinx/Vivado/2025.1/bin")
    # Fall back to bare names; will fail if not in PATH
    XVLOG = f"xvlog{EXE_SUFFIX}"
    XELAB = f"xelab{EXE_SUFFIX}"
    XSIM  = f"xsim{EXE_SUFFIX}"
else:
    print(f"[INFO] Vivado found at: {_VIVADO_BIN}")
    XVLOG = os.path.join(_VIVADO_BIN, f"xvlog{EXE_SUFFIX}")
    XELAB = os.path.join(_VIVADO_BIN, f"xelab{EXE_SUFFIX}")
    XSIM  = os.path.join(_VIVADO_BIN, f"xsim{EXE_SUFFIX}")

def run_step(name: str, cmd: list, cwd: str = ROOT_DIR) -> tuple[bool, float, str]:
    print(f"\n[RUNNING] {name}...")
    start = time.time()
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300
        )
        duration = time.time() - start
        passed = (proc.returncode == 0)
        return passed, duration, proc.stdout
    except Exception as e:
        duration = time.time() - start
        return False, duration, str(e)

def run_simulation_test(tb_file: str) -> tuple[bool, float, str]:
    tb_name = os.path.splitext(os.path.basename(tb_file))[0]
    os.makedirs(SIM_BUILD_DIR, exist_ok=True)
    
    # Sync firmware hex files into sim_build so relative paths resolve cleanly
    for sub in ["bootrom", "tests", os.path.join("tests", "boot_matrix")]:
        dst_dir = os.path.join(SIM_BUILD_DIR, "firmware", sub)
        os.makedirs(dst_dir, exist_ok=True)
        src_dir = os.path.join(ROOT_DIR, "firmware", sub)
        if os.path.exists(src_dir):
            for f in os.listdir(src_dir):
                if f.endswith(".hex") or f.endswith(".bin"):
                    shutil.copy2(os.path.join(src_dir, f), os.path.join(dst_dir, f))
    
    # Collect all RTL source files
    rtl_files = []
    for root, _, files in os.walk(os.path.join(ROOT_DIR, "rtl")):
        for f in files:
            if f.endswith(".v") or f.endswith(".sv"):
                rtl_files.append(os.path.join(root, f))

    # 1. xvlog
    xvlog_cmd = [XVLOG, "-sv", "-i", ROOT_DIR] + rtl_files + [os.path.abspath(tb_file)]
    pass_vlog, dur_vlog, out_vlog = run_step(f"Compile {tb_name} (xvlog)", xvlog_cmd, cwd=SIM_BUILD_DIR)
    if not pass_vlog:
        return False, dur_vlog, f"Compilation failed:\n{out_vlog}"
        
    # 2. xelab
    snap_name = f"{tb_name}_sim"
    xelab_cmd = [XELAB, "-debug", "typical", tb_name, "-s", snap_name]
    pass_elab, dur_elab, out_elab = run_step(f"Elaborate {tb_name} (xelab)", xelab_cmd, cwd=SIM_BUILD_DIR)
    if not pass_elab:
        return False, dur_vlog + dur_elab, f"Elaboration failed:\n{out_elab}"
        
    # 3. xsim
    xsim_cmd = [XSIM, snap_name, "-R"]
    pass_sim, dur_sim, out_sim = run_step(f"Execute {tb_name} (xsim)", xsim_cmd, cwd=SIM_BUILD_DIR)
    total_dur = dur_vlog + dur_elab + dur_sim
    if not pass_sim or "TEST FAILED" in out_sim or "Fatal:" in out_sim:
        return False, total_dur, f"Simulation failed:\n{out_sim}"
        
    return True, total_dur, out_sim

def main():
    parser = argparse.ArgumentParser(description="Run full Ascon RTL regression suite.")
    parser.add_argument("--skip-kats", action="store_true", help="Skip official NIST KAT tests")
    parser.add_argument("--skip-formal", action="store_true", help="Skip formal CTL model checking")
    parser.add_argument("--skip-sim", action="store_true", help="Skip SystemVerilog RTL simulation")
    args = parser.parse_args()

    suite_start = time.time()
    print("=" * 80)
    print("ASCON AEAD & HASH SECURE BOOT RTL REGRESSION SUITE")
    print(f"Working Directory: {ROOT_DIR}")
    print(f"Timestamp:         {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}")
    print("=" * 80)

    results = []

    # 1. Golden Model KATs
    if not args.skip_kats:
        kat_script = os.path.join(ROOT_DIR, "reference", "run_kats.py")
        p, dur, out = run_step("Golden Model NIST KAT Suite (2,120 vectors)", [sys.executable, kat_script])
        results.append(("Golden Model (NIST KATs)", p, dur, out))
    else:
        print("\n[SKIPPED] Golden Model KAT Suite")

    # 2. Formal Verification
    if not args.skip_formal:
        formal_script = os.path.join(ROOT_DIR, "formal", "ctl", "verify_smv.py")
        p, dur, out = run_step("Formal CTL Model Checking (AG jump->hash_ok)", [sys.executable, formal_script])
        results.append(("Formal CTL Verification", p, dur, out))
    else:
        print("\n[SKIPPED] Formal CTL Verification")

    # 3. SystemVerilog Unit and Integration Tests
    if not args.skip_sim:
        tb_unit_dir = os.path.join(ROOT_DIR, "tb", "unit")
        unit_tests = [os.path.join(tb_unit_dir, f) for f in os.listdir(tb_unit_dir) if f.startswith("tb_") and f.endswith(".sv")]
        for tb in sorted(unit_tests):
            tb_name = os.path.basename(tb)
            p, dur, out = run_simulation_test(tb)
            results.append((f"Unit Sim: {tb_name}", p, dur, out))

        tb_int_dir = os.path.join(ROOT_DIR, "tb", "integration")
        if os.path.exists(tb_int_dir):
            int_tests = [os.path.join(tb_int_dir, f) for f in os.listdir(tb_int_dir) if f.startswith("tb_") and f.endswith(".sv")]
            for tb in sorted(int_tests):
                tb_name = os.path.basename(tb)
                p, dur, out = run_simulation_test(tb)
                results.append((f"Integration Sim: {tb_name}", p, dur, out))
    else:
        print("\n[SKIPPED] SystemVerilog RTL Simulation")

    # Print Summary Table
    total_duration = time.time() - suite_start
    print("\n" + "=" * 80)
    print("REGRESSION EXECUTION SUMMARY")
    print("=" * 80)
    print(f"{'Test Suite / Component':<40} {'Status':<12} {'Duration':<10}")
    print("-" * 80)

    all_passed = True
    for name, passed, dur, _ in results:
        status_str = "[PASS]" if passed else "[FAIL]"
        if not passed:
            all_passed = False
        print(f"{name:<40} {status_str:<12} {dur:>6.2f}s")

    print("-" * 80)
    print(f"Total Execution Time: {total_duration:.2f}s")
    print(f"Overall Result:       {'SUCCESS - ALL SUITES PASSED' if all_passed else 'FAILURE DETECTED'}")
    print("=" * 80)

    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
