#!/usr/bin/env python3
# ==============================================================================
# Script: kat_to_vectors.py
# Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
# Purpose: Convert NIST LWC KAT text files into flat $readmemh-compatible
#          hex memory files for use with tb_aead_full.sv and tb_hash_full.sv.
#
# Output files:
#   tb/vectors/aead_kat.mem  — 1089 AEAD vectors
#   tb/vectors/hash_kat.mem  —  1025 Hash vectors
#
# AEAD Record Format (RECORD_WORDS_AEAD = 64 words per vector):
#   Word  0      : Count (decimal vector number)
#   Word  1      : AD length in bytes
#   Word  2      : PT length in bytes
#   Word  3      : Reserved (0)
#   Words  4.. 7 : Key     [127:0] big-endian (key[127:96] in word 4)
#   Words  8..11 : Nonce   [127:0] big-endian
#   Words 12..15 : Tag     [127:0] big-endian (last 16 bytes of CT field)
#   Words 16..23 : AD bytes, little-endian packing (byte0 at [7:0] of word 16)
#                  Padded with zeros to 8 words (32 bytes)
#   Words 24..31 : PT bytes, little-endian packing. Zero-padded to 8 words.
#   Words 32..39 : CT bytes (ciphertext without tag), little-endian. Zero-padded.
#   Words 40..63 : Reserved (0)
#
#   Little-endian packing: byte[0] -> word[7:0], byte[1] -> word[15:8],
#                          byte[2] -> word[23:16], byte[3] -> word[31:24].
#   This matches the AXI streaming convention: data_in[7:0] = first byte.
#   Example: AD = "3031" -> word16 = 0x00003130 (byte0=0x30 at [7:0], byte1=0x31 at [15:8])
#
# Hash Record Format (RECORD_WORDS_HASH = 272 words per vector):
#   Word  0      : Count
#   Word  1      : Message length in bytes
#   Words  2.. 3 : Reserved
#   Words  4..11 : Digest [255:0] big-endian (digest[255:224] in word 4)
#   Words 12..267: Message bytes, little-endian packing. 256 words = 1024 bytes max.
#                  (Hash KAT goes up to 1024 bytes = Count 1025)
#
# [SPEC] KAT files: reference/kat/LWC_AEAD_KAT_128_128.txt (1089 vectors)
#                   reference/kat/LWC_HASH_KAT_128_256.txt  (1025 vectors)
# ==============================================================================

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KAT_AEAD = ROOT / "reference" / "kat" / "LWC_AEAD_KAT_128_128.txt"
KAT_HASH = ROOT / "reference" / "kat" / "LWC_HASH_KAT_128_256.txt"
VECTORS_DIR = ROOT / "tb" / "vectors"

RECORD_WORDS_AEAD = 64
# Hash record layout:
#   Word  0      : Count
#   Word  1      : Message length in bytes
#   Words  2.. 3 : Reserved (0)
#   Words  4..11 : Digest [255:0] big-endian (digest[255:224] in word 4)
#   Words 12..267: Message bytes, little-endian packing. 256 words = 1024 bytes max.
#                  (Hash KAT goes up to 1024 bytes = Count 1025)
# Total = 4 + 8 + 256 = 268, rounded to 272 for 8-word alignment.
RECORD_WORDS_HASH = 272

def bytes_to_le_words(data: bytes, num_words: int) -> list:
    """Pack byte array into 32-bit little-endian words, zero-padded to num_words."""
    words = []
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        # Little-endian: byte[0] at bits[7:0]
        val = 0
        for j, b in enumerate(chunk):
            val |= (b << (8 * j))
        words.append(val)
    # Zero-pad
    while len(words) < num_words:
        words.append(0)
    return words[:num_words]

def bytes_to_be_words(data: bytes, num_words: int) -> list:
    """Pack byte array into 32-bit big-endian words, zero-padded to num_words."""
    words = []
    # Pad data to multiple of 4 first
    padded = data + b'\x00' * ((-len(data)) % 4)
    for i in range(0, len(padded), 4):
        chunk = padded[i:i+4]
        val = (chunk[0] << 24) | (chunk[1] << 16) | (chunk[2] << 8) | chunk[3]
        words.append(val)
    while len(words) < num_words:
        words.append(0)
    return words[:num_words]

def parse_kat_blocks(filepath: Path) -> list:
    """Parse LWC KAT text file into list of field dicts."""
    text = filepath.read_text(encoding='utf-8', errors='replace')
    blocks = []
    for block in text.split('\n\n'):
        block = block.strip()
        if not block:
            continue
        fields = {}
        for line in block.splitlines():
            if ' = ' in line:
                k, v = line.split(' = ', 1)
                fields[k.strip()] = v.strip()
        if 'Count' in fields:
            blocks.append(fields)
    return blocks

def hex_to_bytes(h: str) -> bytes:
    """Convert hex string (possibly empty) to bytes."""
    h = h.strip()
    if not h:
        return b''
    return bytes.fromhex(h)

def convert_aead_kats():
    print(f"[AEAD] Parsing: {KAT_AEAD}")
    blocks = parse_kat_blocks(KAT_AEAD)
    print(f"[AEAD] Found {len(blocks)} vectors")

    VECTORS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = VECTORS_DIR / "aead_kat.mem"

    max_ad = max_pt = 0
    edge_counts = []  # track edge-case lengths

    with open(out_path, 'w') as f:
        for b in blocks:
            count   = int(b['Count'])
            key     = hex_to_bytes(b.get('Key', ''))
            nonce   = hex_to_bytes(b.get('Nonce', ''))
            pt      = hex_to_bytes(b.get('PT', ''))
            ad      = hex_to_bytes(b.get('AD', ''))
            ct_full = hex_to_bytes(b.get('CT', ''))

            # CT field = ciphertext bytes + 16-byte tag
            tag = ct_full[-16:]
            ct  = ct_full[:-16]

            assert len(ct) == len(pt), \
                f"Count {count}: CT length {len(ct)} != PT length {len(pt)}"
            assert len(tag) == 16, f"Count {count}: tag length {len(tag)} != 16"

            max_ad = max(max_ad, len(ad))
            max_pt = max(max_pt, len(pt))

            # Check edge cases
            for edge in [0, 1, 7, 8, 9, 15, 16, 17, 31, 32, 33]:
                if len(ad) == edge or len(pt) == edge:
                    edge_counts.append((count, len(ad), len(pt)))
                    break

            # Build record (64 words)
            record = [0] * RECORD_WORDS_AEAD
            record[0] = count
            record[1] = len(ad)
            record[2] = len(pt)
            record[3] = 0

            # Key, Nonce, Tag — big-endian 128-bit values stored as 4 BE words each
            key_w   = bytes_to_be_words(key,   4)
            nonce_w = bytes_to_be_words(nonce, 4)
            tag_w   = bytes_to_be_words(tag,   4)
            for i, w in enumerate(key_w):   record[4  + i] = w
            for i, w in enumerate(nonce_w): record[8  + i] = w
            for i, w in enumerate(tag_w):   record[12 + i] = w

            # AD, PT, CT — little-endian byte packing into 8 words each
            ad_w = bytes_to_le_words(ad, 8)
            pt_w = bytes_to_le_words(pt, 8)
            ct_w = bytes_to_le_words(ct, 8)
            for i, w in enumerate(ad_w): record[16 + i] = w
            for i, w in enumerate(pt_w): record[24 + i] = w
            for i, w in enumerate(ct_w): record[32 + i] = w

            # Write 64 hex words, one per line
            for w in record:
                f.write(f"{w:08x}\n")

    print(f"[AEAD] Written: {out_path}  ({len(blocks)} records x {RECORD_WORDS_AEAD} words)")
    print(f"[AEAD] Max AD: {max_ad} bytes, Max PT: {max_pt} bytes")
    print(f"[AEAD] Edge-case vectors (lengths 0,1,7,8,9,15,16,17,31,32,33): {len(edge_counts)}")
    return len(blocks)

def convert_hash_kats():
    print(f"\n[HASH] Parsing: {KAT_HASH}")
    blocks = parse_kat_blocks(KAT_HASH)
    print(f"[HASH] Found {len(blocks)} vectors")

    out_path = VECTORS_DIR / "hash_kat.mem"
    max_msg = 0
    edge_counts = []

    with open(out_path, 'w') as f:
        for b in blocks:
            count  = int(b['Count'])
            msg    = hex_to_bytes(b.get('Msg', ''))
            digest = hex_to_bytes(b.get('MD', ''))

            assert len(digest) == 32, f"Count {count}: digest length {len(digest)} != 32"
            max_msg = max(max_msg, len(msg))

            for edge in [0, 1, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65,
                         127, 128, 255, 256]:
                if len(msg) == edge:
                    edge_counts.append((count, len(msg)))
                    break

            # Build record (272 words)
            record = [0] * RECORD_WORDS_HASH
            record[0] = count
            record[1] = len(msg)
            record[2] = 0
            record[3] = 0

            # Digest — big-endian 256-bit value stored as 8 BE words
            digest_w = bytes_to_be_words(digest, 8)
            for i, w in enumerate(digest_w): record[4 + i] = w

            # Message — little-endian byte packing into 256 words (1024 bytes max)
            msg_w = bytes_to_le_words(msg, 256)
            for i, w in enumerate(msg_w): record[12 + i] = w

            for w in record:
                f.write(f"{w:08x}\n")

    print(f"[HASH] Written: {out_path}  ({len(blocks)} records x {RECORD_WORDS_HASH} words)")
    print(f"[HASH] Max Msg: {max_msg} bytes")
    print(f"[HASH] Edge-case vectors: {len(edge_counts)}")
    return len(blocks)

if __name__ == "__main__":
    n_aead = convert_aead_kats()
    n_hash = convert_hash_kats()
    print(f"\n[DONE] AEAD: {n_aead} vectors, Hash: {n_hash} vectors")
    print(f"       Files in: {VECTORS_DIR}")
    print(f"       Use $readmemh in tb_aead_full.sv and tb_hash_full.sv")

