# PDFium WASI 构建指南

本文档记录了将 PDFium 移植到 WASI (WebAssembly System Interface) 平台的完整步骤。

## 目录

1. [环境要求](#环境要求)
2. [快速开始](#快速开始)
3. [详细构建步骤](#详细构建步骤)
4. [关键配置说明](#关键配置说明)
5. [修改的文件列表](#修改的文件列表)
6. [常见问题与解决方案](#常见问题与解决方案)
7. [运行 WASM 模块](#运行-wasm-模块)

---

## 环境要求

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| WASI-SDK | 30.0 | https://github.com/WebAssembly/wasi-sdk/releases |
| wasmtime | 41.0+ | WASI 运行时，需要支持 exceptions proposal |
| GN | PDFium 自带 | 构建系统 |
| ninja | 任意版本 | 构建工具 |

### Windows 环境配置

```bash
# 安装 WASI-SDK 到 /opt/wasi-sdk/
# 或修改 build/toolchain/wasi/BUILD.gn 中的 wasi_sdk_path

# 安装 wasmtime (MSYS2/MinGW)
pacman -S mingw-w64-x86_64-wasmtime
```

---

## 快速开始

```bash
# 1. 生成构建文件
buildtools/win/gn.exe gen out/wasi --args='target_os="wasi" target_cpu="wasm" is_clang=true is_debug=false use_custom_libcxx=false pdf_enable_v8=false pdf_enable_xfa=false pdf_use_skia=false is_component_build=false pdf_is_standalone=true pdf_is_complete_lib=true pdf_use_partition_alloc=false pdf_bundle_freetype=true use_system_zlib=false symbol_level=0 clang_use_chrome_plugins=false treat_warnings_as_errors=false'

# 2. 编译 PDFium 静态库
ninja -C out/wasi pdfium

# 3. 链接 WASM 模块
./build_wasi.sh

# 4. 运行测试
wasmtime run -W exceptions=y out/wasi/pdfium.wasm
```

---

## 详细构建步骤

### 步骤 1: 配置 WASI 工具链

工具链配置文件位于 `build/toolchain/wasi/BUILD.gn`：

```gn
wasi_sdk_path = "C:/msys64/opt/wasi-sdk/wasi-sdk-30.0-x86_64-windows"
wasi_sysroot = "$wasi_sdk_path/share/wasi-sysroot"

# 关键编译标志
_wasi_common_flags = "--sysroot=$wasi_sysroot -fvisibility=default -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_SIGNAL -mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false"
```

**关键标志说明：**
- `-D_WASI_EMULATED_MMAN`: 启用 mmap 模拟
- `-D_WASI_EMULATED_SIGNAL`: 启用信号模拟
- `-mllvm -wasm-enable-sjlj`: 启用 setjmp/longjmp 支持
- `-mllvm -wasm-use-legacy-eh=false`: **关键！使用新的异常处理格式，与 wasmtime 兼容**

### 步骤 2: 配置构建参数

创建 `out/wasi/args.gn`：

```gn
target_os = "wasi"
target_cpu = "wasm"
is_clang = true
is_debug = false
use_custom_libcxx = false
pdf_enable_v8 = false      # 禁用 V8 JavaScript 引擎
pdf_enable_xfa = false     # 禁用 XFA 表单
pdf_use_skia = false       # 禁用 Skia 图形库
is_component_build = false
pdf_is_standalone = true
pdf_is_complete_lib = true
pdf_use_partition_alloc = false
pdf_bundle_freetype = true
use_system_zlib = false
symbol_level = 0
clang_use_chrome_plugins = false
treat_warnings_as_errors = false
```

### 步骤 3: 编译静态库

```bash
ninja -C out/wasi pdfium
```

编译输出：
- `out/wasi/obj/libpdfium.a` (~13MB)
- `out/wasi/obj/third_party/*/lib*.a` (第三方库)

### 步骤 4: 链接 WASM 模块

使用 `build_wasi.sh` 脚本：

```bash
#!/bin/bash
WASI_SDK="/opt/wasi-sdk/wasi-sdk-30.0-x86_64-windows"
WASI_SYSROOT="$WASI_SDK/share/wasi-sysroot"

# 收集所有静态库
LIBS=$(find out/wasi/obj -name "*.a" | tr '\n' ' ')

# 编译测试程序
"$WASI_SDK/bin/wasm32-wasi-clang++" \
  --sysroot="$WASI_SYSROOT" \
  -fvisibility=default \
  -D_WASI_EMULATED_MMAN \
  -D_WASI_EMULATED_SIGNAL \
  -mllvm -wasm-enable-sjlj \
  -mllvm -wasm-use-legacy-eh=false \
  -c samples/simple_wasi.c \
  -o out/wasi/simple_wasi.o \
  -I. \
  -Ithird_party/freetype/src/include

# 链接
"$WASI_SDK/bin/wasm32-wasi-clang++" \
  --sysroot="$WASI_SYSROOT" \
  -fvisibility=default \
  -D_WASI_EMULATED_MMAN \
  -D_WASI_EMULATED_SIGNAL \
  -mllvm -wasm-enable-sjlj \
  -mllvm -wasm-use-legacy-eh=false \
  out/wasi/simple_wasi.o \
  $LIBS \
  -lsetjmp \
  -lwasi-emulated-mman \
  -lwasi-emulated-signal \
  -o out/wasi/pdfium.wasm
```

---

## 关键配置说明

### 1. 异常处理配置

WASI 的 setjmp/longjmp 需要 WebAssembly 异常处理提案支持。关键配置：

```
-mllvm -wasm-enable-sjlj           # 启用 setjmp/longjmp
-mllvm -wasm-use-legacy-eh=false   # 使用新格式（非 legacy）
```

**重要：** 必须使用 `-wasm-use-legacy-eh=false`，否则生成的 legacy exception 指令不被 wasmtime 支持。

### 2. WASI 模拟库

链接时需要以下库：
- `-lsetjmp`: setjmp/longjmp 实现
- `-lwasi-emulated-mman`: mmap 模拟
- `-lwasi-emulated-signal`: 信号模拟

### 3. 平台检测

在 `build/config/BUILDCONFIG.gn` 中添加：

```gn
is_wasi = current_os == "wasi"
is_wasm = current_os == "emscripten" || current_os == "wasi"
is_posix = !is_win && !is_fuchsia && !is_wasi
```

---

## 修改的文件列表

### 构建系统文件

| 文件 | 修改内容 |
|------|---------|
| `build/config/BUILDCONFIG.gn` | 添加 WASI 平台检测，设置默认工具链 |
| `build/toolchain/wasi/BUILD.gn` | WASI-SDK 工具链配置（新建） |

### 第三方库文件

| 文件 | 修改内容 |
|------|---------|
| `third_party/icu/source/common/unicode/platform.h` | 添加 `U_PF_WASI` 平台定义 |
| `third_party/icu/source/common/putilimp.h` | 禁用 tzname/timezone/tzset |
| `third_party/abseil-cpp/absl/debugging/failure_signal_handler.cc` | 禁用信号处理 |
| `third_party/libopenjpeg/opj_includes.h` | 禁用 fseeko/ftello |
| `core/fxcrt/BUILD.gn` | 为 WASI 添加 POSIX 文件访问支持 |

### 示例文件

| 文件 | 说明 |
|------|------|
| `samples/simple_wasi.c` | WASI 测试程序（新建） |
| `samples/simple_wasi.gn` | 测试程序构建配置（新建） |
| `build_wasi.sh` | WASM 链接脚本（新建） |

---

## 常见问题与解决方案

### Q1: `undefined symbol: __wasm_setjmp`

**原因：** 未启用 setjmp/longjmp 支持或使用了 legacy 异常格式。

**解决方案：**
```bash
# 添加编译标志
-mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false

# 链接时添加
-lsetjmp
```

### Q2: `legacy_exceptions feature required for try instruction`

**原因：** wasmtime 不支持 legacy exception 格式。

**解决方案：**
```bash
# 使用新异常格式
-mllvm -wasm-use-legacy-eh=false
```

### Q3: `Setjmp/longjmp support requires Exception handling support`

**原因：** WASI SDK 的 setjmp.h 检查 `__wasm_exception_handling__` 宏。

**解决方案：** 该宏由 `-mllvm -wasm-enable-sjlj` 自动定义，确保使用此标志。

### Q4: ICU 编译错误 `tzname/timezone/tzset not available`

**原因：** WASI 不支持这些 POSIX 时区函数。

**解决方案：** 在 `putilimp.h` 中为 WASI 平台禁用这些宏：
```c
#elif U_PLATFORM == U_PF_WASI
   /* WASI does not support tzname */
#else
#   define U_TZNAME tzname
#endif
```

### Q5: `FX_Folder::OpenFolder` undefined symbol

**原因：** WASI 没有对应的文件系统枚举实现。

**解决方案：** 在 `core/fxcrt/BUILD.gn` 中为 WASI 添加 POSIX 实现：
```gn
if (is_posix || is_wasi) {
  sources += [ "fx_folder_posix.cpp" ]
}
```

---

## 运行 WASM 模块

### 使用 wasmtime

```bash
# 启用异常处理支持
wasmtime run -W exceptions=y out/wasi/pdfium.wasm

# 完整命令示例
/mingw64/bin/wasmtime.exe run -W exceptions=y out/wasi/pdfium.wasm
```

### 预期输出

```
PDFium WASI Test
================

PDFium library initialized
Created blank document
Created page (640x480)
Page dimensions: 640.0x480.0
Page closed
Document closed
PDFium destroyed

Test completed successfully!
```

---

## 输出文件

| 文件 | 大小 | 说明 |
|------|------|------|
| `out/wasi/obj/libpdfium.a` | ~13MB | PDFium 静态库 |
| `out/wasi/pdfium.wasm` | ~6MB | 最终 WASM 模块 |

---

## 参考资源

- [WASI-SDK 发布页面](https://github.com/WebAssembly/wasi-sdk/releases)
- [wasmtime 文档](https://docs.wasmtime.dev/)
- [WebAssembly 异常处理提案](https://github.com/WebAssembly/proposals?tab=readme-ov-file#phase-3---implementation-phase-cg--wg)
- [PDFium 源码](https://pdfium.googlesource.com/pdfium/)

---

## 更新日志

- **2024-03-18**: 初始版本
- **2024-03-19**: 添加渲染功能测试，，完成 PDFium WASI 移植
