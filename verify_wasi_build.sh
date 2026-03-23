#!/bin/bash
# Test script for PDFium WASI build

set -e

echo "========================================"
echo "PDFium WASI Build Verification"
echo "========================================"
echo ""

# Check wasmtime
echo "1. Checking wasmtime runtime..."
if command -v /mingw64/bin/wasmtime.exe &> /dev/null; then
    echo "   ✓ wasmtime found: $(/mingw64/bin/wasmtime.exe --version)"
else
    echo "   ✗ wasmtime not found"
    exit 1
fi
echo ""

# Check WASM file
echo "2. Checking WASM module..."
if [ -f "out/wasi/pdfium_wasi.wasm" ]; then
    SIZE=$(ls -lh out/wasi/pdfium_wasi.wasm | awk '{print $5}')
    echo "   ✓ WASM module: out/wasi/pdfium_wasi.wasm ($SIZE)"
    file out/wasi/pdfium_wasi.wasm
else
    echo "   ✗ WASM module not found"
    exit 1
fi
echo ""

# Check static library
echo "3. Checking static library..."
if [ -f "out/wasi/obj/libpdfium.a" ]; then
    SIZE=$(ls -lh out/wasi/obj/libpdfium.a | awk '{print $5}')
    echo "   ✓ Static library: out/wasi/obj/libpdfium.a ($SIZE)"

    # Verify it contains WASM objects
    ar t out/wasi/obj/libpdfium.a | head -3 | while read obj; do
        echo "     - $obj"
    done
    echo "     ..."
else
    echo "   ✗ Static library not found"
    exit 1
fi
echo ""

# Run WASM module
echo "4. Running WASM module..."
echo "   $ /mingw64/bin/wasmtime.exe run --dir . -W exceptions=y out/wasi/pdfium_wasi.wasm"
echo ""
/mingw64/bin/wasmtime.exe run --dir . -W exceptions=y out/wasi/pdfium_wasi.wasm
EXIT_CODE=$?
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "========================================"
    echo "✓ ALL TESTS PASSED!"
    echo "========================================"
    echo ""
    echo "PDFium WASI is ready to use!"
    echo ""
    echo "Files:"
    echo "  - out/wasi/obj/libpdfium.a        (Static library, $(ls -lh out/wasi/obj/libpdfium.a | awk '{print $5}'))"
    echo "  - out/wasi/pdfium_wasi.wasm        (WASM module, $(ls -lh out/wasi/pdfium_wasi.wasm | awk '{print $5}'))"
    echo ""
    echo "Usage:"
    echo "  ./build_wasi.sh [build|link|all]"
    echo ""
    echo "To run the WASM module:"
    echo "  wasmtime run --dir . -W exceptions=y out/wasi/pdfium_wasi.wasm"
else
    echo "========================================"
    echo "✗ TEST FAILED (exit code: $EXIT_CODE)"
    echo "========================================"
    exit $EXIT_CODE
fi
