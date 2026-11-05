#!/usr/bin/env python3
"""
scripts/check_doc_links.py
Validates that all local relative links in documentation files resolve to existing files on disk.
Fulfills Task A6: Markdown Link Integrity Checker
"""

import os
import sys
import re
from typing import List, Tuple

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# Directories to validate
SCAN_DIRS = ["docs", "results"]

def find_markdown_files() -> List[str]:
    md_files = []
    # Also check root README.md and AGENTS.md
    for root_f in ["README.md", "AGENTS.md"]:
        p = os.path.join(ROOT_DIR, root_f)
        if os.path.exists(p):
            md_files.append(p)

    for d in SCAN_DIRS:
        full_d = os.path.join(ROOT_DIR, d)
        if os.path.exists(full_d):
            for root, _, files in os.walk(full_d):
                for f in files:
                    if f.endswith(".md"):
                        md_files.append(os.path.join(root, f))
    return md_files

# Regex to match markdown links [text](link)
LINK_PATTERN = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')

def validate_links() -> Tuple[int, int, List[str]]:
    total_links = 0
    broken_links = []
    
    md_files = find_markdown_files()
    for md_path in md_files:
        rel_doc = os.path.relpath(md_path, ROOT_DIR)
        doc_dir = os.path.dirname(md_path)
        
        try:
            with open(md_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
        except Exception as e:
            broken_links.append(f"{rel_doc}: Error reading file: {e}")
            continue
            
        for match in LINK_PATTERN.finditer(content):
            label, link = match.group(1), match.group(2).strip()
            
            # Skip external web URLs
            if link.startswith("http://") or link.startswith("https://") or link.startswith("mailto:"):
                continue
            
            # Skip internal document anchors (#section)
            if link.startswith("#"):
                continue
                
            total_links += 1
            
            # Strip target anchors if present (path#anchor)
            target_path = link.split("#")[0].strip()
            if not target_path:
                continue
                
            # Resolve relative link against doc_dir
            resolved = os.path.normpath(os.path.join(doc_dir, target_path))
            
            if not os.path.exists(resolved):
                broken_links.append(
                    f"{rel_doc}: Broken link [{label}]({link}) -> resolved to non-existent: {os.path.relpath(resolved, ROOT_DIR)}"
                )

    return total_links, len(broken_links), broken_links

def main():
    print("=" * 80)
    print("RUNNING DOCUMENTATION RELATIVE LINK INTEGRITY CHECKER")
    print(f"Root: {ROOT_DIR}")
    print("=" * 80)
    
    total, broken_count, broken_list = validate_links()
    print(f"Scanned {total} relative documentation links across repository.")
    
    if broken_count == 0:
        print("\n[SUCCESS] 100% of relative markdown links resolve to existing files on disk (0 broken).")
        return 0
    else:
        print(f"\n[FAILED] Found {broken_count} broken relative links:")
        for err in broken_list:
            print(f"  - {err}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

