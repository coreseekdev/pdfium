#!/bin/bash
# PDFium WASI Build Script — no build/ patches required.
# Uses custom_toolchain override to inject WASI SDK toolchain.
#
# Usage: ./build_wasi.sh [build|link|all] [output_name]
#
# Commands:
#   build  - gn gen + ninja (default)
#   link   - Link sample WASI binary from built .a files
#   all    - build + link
#
# Environment:
#   WASI_SDK_PATH - Path to WASI SDK (default: /opt/wasi-sdk/wasi-sdk-30.0-x86_64-windows)

set -e

PDFIUM_ROOT="$(cd "$(dirname "$0")" && pwd)"
COMMAND="${1:-build}"
OUTPUT_NAME="${2:-pdfium_wasi}"
WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk/wasi-sdk-30.0-x86_64-windows}"
WASI_SYSROOT="$WASI_SDK_PATH/share/wasi-sysroot"

echo "PDFium WASI Build Script"
echo "========================"
echo "PDFium Root:   $PDFIUM_ROOT"
echo "WASI SDK:      $WASI_SDK_PATH"
echo "Command:       $COMMAND"
echo ""

# --- Step 1: GN gen + Ninja build ---
do_build() {
    # Setup args.gn
    mkdir -p "$PDFIUM_ROOT/out/wasi"
    if [ ! -f "$PDFIUM_ROOT/out/wasi/args.gn" ]; then
        # Copy template and substitute wasi_sdk_path from environment
        sed "s|wasi_sdk_path = .*|wasi_sdk_path = \"$WASI_SDK_PATH\"|" \
            "$PDFIUM_ROOT/args.wasi.gn" > "$PDFIUM_ROOT/out/wasi/args.gn"
        echo "Created out/wasi/args.gn (wasi_sdk_path = $WASI_SDK_PATH)"
    else
        echo "Using existing out/wasi/args.gn"
    fi
    echo ""

    echo "--- Running gn gen ---"
    gn gen "$PDFIUM_ROOT/out/wasi"
    echo ""

    echo "--- Running ninja ---"
    ninja -C "$PDFIUM_ROOT/out/wasi" pdfium
    echo ""
    echo "Build complete. Static libraries in out/wasi/obj/"
}

# --- Step 2: Link sample WASM module ---
do_link() {
    CLANGXX="$WASI_SDK_PATH/bin/wasm32-wasi-clang++"
    COMMON_FLAGS="--sysroot=$WASI_SYSROOT -fvisibility=default -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_SIGNAL -mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false"

    # Collect all static libraries
    echo "--- Linking WASM module ---"
    ALL_LIBS=$(find "$PDFIUM_ROOT/out/wasi/obj" -name "*.a" 2>/dev/null | tr '\n' ' ')
    LIB_COUNT=$(echo $ALL_LIBS | wc -w)
    echo "Found $LIB_COUNT static libraries"

    SAMPLE_SRC="$PDFIUM_ROOT/samples/pdfium_wasi.c"
    if [ ! -f "$SAMPLE_SRC" ]; then
        echo "Error: $SAMPLE_SRC not found"
        exit 1
    fi

    echo "Compiling pdfium_wasi.c..."
    $CLANGXX $COMMON_FLAGS -c "$SAMPLE_SRC" \
        -o "$PDFIUM_ROOT/out/wasi/pdfium_wasi.o" \
        -I"$PDFIUM_ROOT" \
        -I"$PDFIUM_ROOT/third_party/freetype/src/include" \
        -DOPJ_STATIC \
        -DPNG_USER_CONFIG \
        -DPNG_STATIC \
        -DNVALGRIND \
        -DDYNAMIC_ANNOTATIONS_ENABLED=0 \
        -DABSL_ALLOCATOR_NOTHROW=1

    echo "Linking WASM module..."
    $CLANGXX $COMMON_FLAGS \
        "$PDFIUM_ROOT/out/wasi/pdfium_wasi.o" \
        $ALL_LIBS \
        -lsetjmp \
        -lwasi-emulated-mman \
        -lwasi-emulated-signal \
        -o "$PDFIUM_ROOT/out/wasi/${OUTPUT_NAME}.wasm"

    echo ""
    echo "Done! Output: out/wasi/${OUTPUT_NAME}.wasm"
    ls -lh "$PDFIUM_ROOT/out/wasi/${OUTPUT_NAME}.wasm"
    echo ""

    # Verify it's a valid WASM file
    echo "Verifying WASM format:"
    file "$PDFIUM_ROOT/out/wasi/${OUTPUT_NAME}.wasm"
    echo ""
    echo "Run with:"
    echo "  wasmtime run --dir . -W exceptions=y out/wasi/${OUTPUT_NAME}.wasm <pdf_file>"
}

# --- Dispatch ---
case "$COMMAND" in
    build)
        do_build
        ;;
    link)
        do_link
        ;;
    all)
        do_build
        do_link
        ;;
    *)
        echo "Usage: $0 [build|link|all] [output_name]"
        exit 1
        ;;
esac
