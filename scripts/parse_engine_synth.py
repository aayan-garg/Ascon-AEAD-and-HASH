import glob, os, re

variants = [
    'mode_ctrl_1r_wrap',
    'mode_ctrl_1r_espresso_wrap',
    'mode_ctrl_2r_wrap',
    'mode_ctrl_half_wrap',
    'mode_ctrl_serial32_wrap'
]

print(f"{'Engine Variant':<30} {'LUT':<8} {'FF':<8} {'WNS (ns)':<10} {'Fmax (MHz)':<12}")
print('-' * 70)

for v in variants:
    util_file = f"results/synthesis/{v}_util.rpt"
    timing_file = f"results/timing/{v}_timing.rpt"
    lut, ff, wns = "N/A", "N/A", "N/A"
    if os.path.exists(util_file):
        with open(util_file, "r") as f:
            for line in f:
                if "Slice LUTs" in line and "Logic" not in line:
                    parts = [p.strip() for p in line.split("|")]
                    if len(parts) >= 3:
                        lut = parts[2]
                if "Slice Registers" in line and "Flip Flop" not in line:
                    parts = [p.strip() for p in line.split("|")]
                    if len(parts) >= 3:
                        ff = parts[2]
    if os.path.exists(timing_file):
        with open(timing_file, "r") as f:
            for line in f:
                if "WNS(ns)" in line:
                    # next non-empty line
                    val_line = next(f)
                    while not val_line.strip() or "---" in val_line:
                        val_line = next(f)
                    parts = val_line.split()
                    if len(parts) >= 1:
                        wns = parts[0]
                    break
    fmax = "N/A"
    if wns != "N/A":
        try:
            wns_val = float(wns)
            req = 10.0
            delay = req - wns_val
            fmax = f"{1000.0 / delay:.2f}" if delay > 0 else "N/A"
        except:
            pass
    print(f"{v:<30} {lut:<8} {ff:<8} {wns:<10} {fmax:<12}")

