// Copyright 2025 PDFium WASI Port
// Simple WASI-compatible PDFium example
//
// This is a minimal example that demonstrates PDFium running on WASI.
// It can be compiled to WebAssembly and run with wasmtime.

#include <stdio.h>
#include <stdlib.h>

#include "public/fpdfview.h"
#include "public/fpdf_edit.h"
#include "public/fpdf_doc.h"

int main(int argc, const char* argv[]) {
    printf("PDFium WASI - WebAssembly PDF Library Demo\n");
    printf("===========================================\n\n");

    // Initialize PDFium library
    FPDF_InitLibrary();
    printf("PDFium library initialized successfully!\n\n");

    // Create a test document to verify the API works
    FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
    if (doc) {
        printf("Created new document successfully!\n");
        FPDF_CloseDocument(doc);
        printf("Closed document\n");
    } else {
        printf("Failed to create document\n");
    }

    // Cleanup
    FPDF_DestroyLibrary();
    printf("\nPDFium WASI: Demo complete!\n");
    printf("\nTo process actual PDF files:\n");
    printf("  1. Implement file reading (wasmtime --dir .)\n");
    printf("  2. Use FPDF_LoadMemDocument() with file contents\n");
    printf("  3. Call FPDF_LoadPage() to access pages\n");
    printf("\nRun with: wasmtime run --dir . -W exceptions=y pdfium_wasi.wasm\n");

    return 0;
}
