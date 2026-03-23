# WASI Build Support Patches

## Overview

This directory contains patches that add WebAssembly (WASI) support to the Chromium build system. These patches are automatically applied after `gclient sync` via a DEPS hook.

## Why Patches Are Needed

The `build/` directory is synchronized from Chromium's repository and does not include WebAssembly support. These patches add:

1. **`build/config/rust.gni`** - Add `wasm32-wasi` Rust ABI target
2. **`build/config/clang/BUILD.gn`** - Skip clang runtime libs for WASM, add wasm directory
3. **`build/config/compiler/BUILD.gn`** - Disable `-Wa,--crel` flag (unsupported by WASM)

## Files

- `wasi-build-support.patch` - The unified patch file with all changes
- `apply_wasi_patches.py` - Script to apply the patches (called by DEPS hook)
- `README.md` - This file

## How It Works

### Automatic Application (DEPS Hook)

After `gclient sync`, the DEPS hook automatically calls the patch script:

```python
# In DEPS file
{
  'name': 'apply_wasi_patches',
  'pattern': '.',
  'action': ['python3', 'patches/apply_wasi_patches.py'],
}
```

### Manual Application

To manually apply patches:

```bash
python3 patches/apply_wasi_patches.py
```

### Verifying Patches

Check if patches are applied:

```bash
cd build && git status
```

You should see:
```
M config/clang/BUILD.gn
M config/compiler/BUILD.gn
M config/rust.gni
```

## Updating Patches

If Chromium's `build/` changes and patches need updating:

1. Make changes to files in `build/config/`
2. Regenerate patch:
   ```bash
   cd build && git diff config/ > ../patches/wasi-build-support.patch
   ```
3. Test: `git checkout` changes, then run `python3 patches/apply_wasi_patches.py`

## Long-term Plan

These patches should be contributed upstream to Chromium so they're included by default. Track progress in:

- Chromium issue: [link to issue]
- CL: [link to changelist]

## See Also

- `toolchain/wasi/BUILD.gn` - WASI toolchain configuration
- `args.wasi.gn` - WASI build arguments
- `docs/WASI_BUILD_GUIDE.md` - Complete WASI build guide
