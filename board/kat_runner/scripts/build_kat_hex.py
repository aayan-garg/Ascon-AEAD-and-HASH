#!/usr/bin/env python3
"""
Compile Presentation/kat_board/fw/kat_board.c into a 32-bit $readmemh hex image
(128 KB BRAM padded/word-addressed) via WSL riscv64-unknown-elf-gcc.
"""

import argparse
import os
import struct
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KAT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.abspath(os.path.join(KAT_DIR, "..", "..", "Ascon-AEAD-and-HASH"))


def win_to_wsl(p: str) -> str:
    p = os.path.abspath(p).replace("\\", "/")
    drive = p[0].lower()
    return f"/mnt/{drive}{p[2:]}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-name", default="kat_board_all2114")
    parser.add_argument("--max-hash", type=int, default=1025)
    parser.add_argument("--max-aead", type=int, default=1089)
    args = parser.parse_args()

    # Generate matching kat_vectors.h
    gen_py = os.path.join(SCRIPT_DIR, "gen_kat_header.py")
    hdr_path = os.path.join(KAT_DIR, "fw", "kat_vectors.h")
    subprocess.run(
        ["python", gen_py, "--out", hdr_path, "--max-hash", str(args.max_hash), "--max-aead", str(args.max_aead)],
        check=True,
    )

    ld_wsl = win_to_wsl(os.path.join(KAT_DIR, "fw", "kat.ld"))
    crt0_wsl = win_to_wsl(os.path.join(REPO_ROOT, "firmware", "startup", "crt0.S"))
    src_wsl = win_to_wsl(os.path.join(KAT_DIR, "fw", "kat_board.c"))
    inc_wsl = win_to_wsl(os.path.join(KAT_DIR, "fw"))

    build_dir = os.path.join(KAT_DIR, "build")
    os.makedirs(build_dir, exist_ok=True)
    elf_win = os.path.join(build_dir, f"{args.out_name}.elf")
    bin_win = os.path.join(build_dir, f"{args.out_name}.bin")
    hex_win = os.path.join(build_dir, f"{args.out_name}.hex")

    cmd = (
        f"riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -Wall -Wextra -Werror "
        f"-nostdlib -Wl,-Bstatic -I {inc_wsl} -T {ld_wsl} {crt0_wsl} {src_wsl} -o {win_to_wsl(elf_win)} && "
        f"riscv64-unknown-elf-objcopy -O binary {win_to_wsl(elf_win)} {win_to_wsl(bin_win)} && "
        f"riscv64-unknown-elf-size {win_to_wsl(elf_win)}"
    )
    res = subprocess.run(["wsl", "bash", "-c", cmd], capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"GCC compile failed:\n{res.stdout}\n{res.stderr}")
    print(res.stdout.strip())

    with open(bin_win, "rb") as f:
        bindata = f.read()

    if len(bindata) > 128 * 1024:
        raise RuntimeError(f"Binary size {len(bindata)} exceeds 128 KB BRAM!")

    words = ["00000000"] * 32768
    for i in range(0, len(bindata), 4):
        chunk = bindata[i : i + 4]
        if len(chunk) < 4:
            chunk = chunk + b"\x00" * (4 - len(chunk))
        words[i // 4] = f"{struct.unpack('<I', chunk)[0]:08x}"

    with open(hex_win, "w", encoding="utf-8") as f:
        for w in words:
            f.write(w + "\n")

    print(f"[SUCCESS] {hex_win}: binary={len(bindata)} B ({len(bindata)/1024:.2f} KB), padded=32768 words")


if __name__ == "__main__":
    main()

