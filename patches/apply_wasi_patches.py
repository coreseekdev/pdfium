#!/usr/bin/env python3
# Copyright 2025 PDFium WASI Port
# Applies WASI build support patches to Chromium build/ directory.
#
# This script is called automatically by gclient hooks after sync.
# Usage (manual): python3 patches/apply_wasi_patches.py

import os
import subprocess
import sys

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    patch_file = os.path.join(script_dir, "wasi-build-support.patch")
    build_dir = os.path.join(repo_root, "build")

    print("PDFium WASI: Applying build/ patches...")

    # Check if patch already applied
    result = subprocess.run(
        ["git", "status", "--short", "config/rust.gni"],
        cwd=build_dir,
        capture_output=True,
        text=True
    )

    if "M config/rust.gni" in result.stdout:
        print("  [OK] Patches already applied (rust.gni is modified)")
        return 0

    # Check if patch file exists
    if not os.path.exists(patch_file):
        print(f"  [ERROR] Patch file not found: {patch_file}")
        return 1

    # Apply patch (must run from build/ directory because patch paths are relative)
    result = subprocess.run(
        ["git", "apply", "--check", patch_file],
        cwd=build_dir,
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(f"  [WARN] Patch check failed:\n{result.stderr}")
        print("  Attempting to apply anyway...")

    result = subprocess.run(
        ["git", "apply", patch_file],
        cwd=build_dir,
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(f"  [ERROR] Failed to apply patch:\n{result.stderr}")
        return 1

    print("  [OK] Patches applied successfully")
    return 0

if __name__ == "__main__":
    sys.exit(main())
