#!/usr/bin/env python3
"""
Bare-Metal Firmware Build Script for PicoRV32
Compiles C and assembly into ELF, binary, and 32-bit hex for SystemVerilog $readmemh.
"""

import os
import sys
import subprocess
import struct

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def build_firmware(src_c: str, out_name: str, ram_size_words: int = 4096):
    tests_dir = os.path.join(ROOT_DIR, "firmware", "tests")
    linker_script = "firmware/linker/bringup.ld"
    crt0_asm = "firmware/startup/crt0.S"
    
    elf_path = os.path.join(tests_dir, f"{out_name}.elf")
    bin_path = os.path.join(tests_dir, f"{out_name}.bin")
    hex_path = os.path.join(tests_dir, f"{out_name}.hex")

    # Command to run inside WSL
    wsl_cmd = (
        f"cd /mnt/c/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH && "
        f"riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -nostdlib -Wl,-Bstatic "
        f"-T {linker_script} {crt0_asm} firmware/tests/{src_c} -o firmware/tests/{out_name}.elf && "
        f"riscv64-unknown-elf-objcopy -O binary firmware/tests/{out_name}.elf firmware/tests/{out_name}.bin"
    )

    print(f"[BUILD] Compiling {src_c} via WSL riscv64-unknown-elf-gcc...")
    res = subprocess.run(["wsl", "bash", "-c", wsl_cmd], capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[FAIL] Compilation failed:\n{res.stderr}")
        return False

    # Read binary and convert to 32-bit hex words for Verilog $readmemh
    with open(bin_path, "rb") as f:
        bindata = f.read()

    print(f"[BUILD] Binary size: {len(bindata)} bytes ({len(bindata)//4} words)")

    words = []
    for i in range(0, len(bindata), 4):
        chunk = bindata[i:i+4]
        if len(chunk) < 4:
            chunk = chunk + b"\x00" * (4 - len(chunk))
        val = struct.unpack("<I", chunk)[0]
        words.append(f"{val:08x}")

    # Pad out to RAM size or leave as sparse hex
    with open(hex_path, "w", encoding="utf-8") as f:
        for w in words:
            f.write(w + "\n")

    print(f"[SUCCESS] Generated {hex_path} with {len(words)} instructions/words.")
    return True

if __name__ == "__main__":
    src = "gpio_toggle.c"
    out = "gpio_toggle"
    if len(sys.argv) > 1:
        src = sys.argv[1]
    if len(sys.argv) > 2:
        out = sys.argv[2]
    build_firmware(src, out)
