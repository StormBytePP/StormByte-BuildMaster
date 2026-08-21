# StormByte BuildMaster

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Meson](https://img.shields.io/badge/Meson-supported-orange)
![Ninja](https://img.shields.io/badge/Ninja-supported-0f4c81)
![Status](https://img.shields.io/badge/status-active-success)

A small **CMake DSL** to configure, build, install and consume external
**CMake** and **Meson** projects as first-class parts of a parent tree —
with **configure-time** stages, explicit targets, coherent environment
propagation, portable static-library bundling, and **controlled failure
propagation** across the dependency graph.

## Table of contents

- [Overview](#overview)
- [Motivation](#motivation)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [Output verbosity and diagnostics](#output-verbosity-and-diagnostics)
- [Fail-fast and stage failure propagation](#fail-fast-and-stage-failure-propagation)
- [Compiler cache (ccache / sccache)](#compiler-cache-ccache--sccache)
- [Platform notes](#platform-notes)
- [Recursive usage](#recursive-usage)
- [Usage modes](#usage-modes)
- [Targets and naming](#targets-and-naming)
- [Static library bundling](#static-library-bundling)
- [API reference (where to look)](#api-reference-where-to-look)
- [Git helpers](#git-helpers)
- [File download & decompress helpers](#file-download--decompress-helpers)
- [Examples](#examples)
- [License](#license)

---

## Overview

BuildMaster generates **configure / build / install** stages while the
parent project is still in the **CMake configure phase**. That lets the
parent:

- inspect installed headers and libraries before the main build
- create deterministic **IMPORTED** targets
- attach `POST_BUILD` / install hooks to real stage targets
- share one install prefix and environment across a dependency tree
- fail the parent when a required external stage fails (headers/libs never
“half present”)

It is **not** only a source fetcher (unlike a pure `FetchContent` workflow):
it orchestrates full external builds. Sources may still be managed with the
included Git helpers, the file download helpers, or any other means.

Typical use cases: bundling FFmpeg and its plugins, multi-bitdepth codecs
(e.g. x265 8/10/12-bit), and mixed CMake + Meson dependency graphs on
Linux, Windows, and macOS (including Apple Silicon).

---

## Motivation

`ExternalProject_Add` configures and builds dependencies **at build time**.
By then it is too late for the parent to:

- branch on configure results
- generate import targets from real artifact paths
- enforce a single, shared install layout

`FetchContent` brings sources into the tree but does not, by itself, provide
a uniform model for multi-system (CMake + Meson) build/install orchestration.

Meson also does **not** reliably inherit the parent environment the way CMake
does (`PKG_CONFIG_PATH`, install prefix, compilers, flags, cache launchers).
Without a control layer, nested Meson setups often fail to find previous
plugins’ `.pc` files or use the wrong toolchain.

Without explicit stage targets and dependency edges, a failed external
compile can still leave the parent compiling against missing headers
(e.g. `mysql.h not found`) while other unrelated bundles keep installing.

BuildMaster fills those gaps with **configure-time** generated scripts,
explicit targets, env runners, and optional **fail-fast** markers so a stage
failure is visible and can stop subsequent work:

```text
<component>_build
<component>_install
```

---

## Comparison

| Capability                              | FetchContent | ExternalProject_Add | BuildMaster          |
|-----------------------------------------|:------------:|:-------------------:|:--------------------:|
| Fetch / manage sources                  | Yes          | Yes                 | Yes (Git helpers)    |
| **Intelligent / cacheable downloads**   | Partial      | Manual              | **Yes (built-in)**   |
| Configure external project              | N/A          | Build time          | **Configure time**   |
| Inspect artifacts before main build     | No           | No                  | **Yes**              |
| Explicit `_build` / `_install` targets  | No           | No                  | **Yes**              |
| Attach post-steps to those targets      | No           | Limited             | **Yes**              |
| Native Meson stages                     | No           | Manual              | **Yes**              |
| Shared install + env propagation        | No           | Manual              | **Yes**              |
| Compiler cache into child builds        | Manual       | Manual              | **Yes**              |
| Portable static archive merge           | No           | Manual              | **Yes**              |
| Safe recursive nesting                  | Fragile      | Fragile             | **Designed for it**  |
| **Fail-fast / skip after stage failure**| No           | Manual              | **Yes (optional)**   |
| **INTERFACE deps on `_install`**        | No           | Manual              | **Yes**              |

---

## Design goals

- Deterministic **configure-time** orchestration
- Coherent environment (`PATH`, `PKG_CONFIG_PATH`, `LIB`, `INCLUDE`,
compilers, flags, optional ccache/sccache)
- **Linux / Windows / macOS** (x86_64 and arm64)
- CMake and Meson behind the same component API
- Generated scripts that are inspectable and CI-friendly
- One initialization, one install root, even in deep dependency trees
- Quiet default logs with **full diagnostics on failure**, optional
**DEBUG** (all stages) and **VERBOSE** (compile stages only)
- Intelligent, cacheable and portable file download / decompression
- Predictable failure behaviour: a broken required component must fail the
parent graph, not surface as a missing include later

---

## Quick start

```cmake
# Optional: enable extra tools (e.g. bundled pkgconf when needed)
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")

add_subdirectory(path/to/buildmaster)
include(path/to/buildmaster/helpers.cmake)

set(_opts "-DENABLE_FOO=ON")
create_cmake_component(
	OUT_FILE
	opus
	"Opus Audio Codec"
	${CMAKE_SOURCE_DIR}/thirdparty/opus
	${CMAKE_BINARY_DIR}/thirdparty/opus_build
	"${_opts}"
	shared
	"opus"          # subcomponent / artifact base name(s)
)
include(${OUT_FILE})
```

After `include(${OUT_FILE})`, stage targets and imported libraries for that
component are available to the rest of the parent project.

---

## Output verbosity and diagnostics

By default each stage prints a short status line (for example
`Compiling …` / `Installing …`) so large dependency graphs stay readable.
“Silent” runners suppress underlying tool stdout/stderr **on success**.

### On failure

Silent runners capture output into a unique temporary file. If the child
command exits non-zero, the log is written to **stderr** (then the temp file
is removed). That way:

- `execute_process(... ERROR_VARIABLE ...)` still receives the full log
- CI consoles show configure/build failures without enabling full verbosity
- parallel jobs do not clash on log paths (`mktemp` / unique names under `%TEMP%`)

Stage exec scripts (`*_build_exec.cmake` / `*_install_exec.cmake` and Meson
equivalents) also report a clear fatal error when the underlying
`cmake --build` / `meson compile` / install command fails.

### Full live output (DEBUG)

```bash
export BUILDMASTER_DEBUG=1
# or: cmake -DBUILDMASTER_DEBUG=ON ...
```

When enabled, silent runners are replaced by the full env runner for
**all** stages that use them (configure, git, meson setup, install, etc.):
underlying tool output is shown live. Prefer this locally when debugging
bootstrap issues; leave it **unset in CI** and rely on failure dumps instead.

### Verbose compiles only (VERBOSE)

```bash
export BUILDMASTER_VERBOSE=1
# or: cmake -DBUILDMASTER_VERBOSE=ON ...
```

When enabled, **only compilation stages** become more chatty:

| Stage | Effect |
|-------|--------|
| `cmake --build` (`*_build`) | Compile runner (live output) + `--verbose` |
| `meson compile` (`*_build`) | Compile runner + `-v` |
| Configure / meson setup | Unchanged (still quiet unless `DEBUG`) |
| `cmake --install` / `meson install` | Unchanged |
| Git / file download helpers | Unchanged |

Internally this is driven by `ENV_RUNNER_COMPILE` (defaults to the silent
runner; switches to the full runner when `BUILDMASTER_VERBOSE` is on) and
by `ENV_CMAKE_COMPILE_COMMAND` / `ENV_MESON_COMPILE_COMMAND`.

**DEBUG does not imply VERBOSE.** Enable both if you want full bootstrap
logs **and** compiler command lines:

| `DEBUG` | `VERBOSE` | Bootstrap tools | Compile command lines |
|---------|-----------|-----------------|------------------------|
| off | off | Quiet (dump on failure) | Quiet |
| on | off | Live | Quiet (no `--verbose` / `-v`) |
| off | on | Quiet (dump on failure) | Live + `--verbose` / `-v` |
| on | on | Live | Live + `--verbose` / `-v` |

Scripts are generated at **configure** time: change `BUILDMASTER_VERBOSE`
or `BUILDMASTER_DEBUG`, then re-run CMake so stage scripts are regenerated.

---

## Fail-fast and stage failure propagation

Large superbuilds often continue after one component fails: other installs
still run, and the parent may compile against a prefix that never received
headers. BuildMaster addresses this in three layers.

### 1. Stage exit codes (always)

Build and install stages run through generated `*_exec.cmake` scripts.
A non-zero exit from `cmake --build`, `meson compile`, `cmake --install`,
or `meson install` fails that stage. Ninja/Make/`cmake --build` then fail
any target that depends on it.

### 2. INTERFACE → `_install` (always)

Component templates (`component_static*.cmake.in`, `component_shared*.cmake.in`)
attach:

```text
add_dependencies(<INTERFACE> <component>_install)
add_dependencies(<IMPORTED lib> <component>_install)
```

So a parent that does:

```cmake
target_link_libraries(MyLib PRIVATE SomeBundledComponent)
```

waits for a **successful** install before treating the component as ready
(headers under `BUILDMASTER_INSTALL_INCLUDEDIR` and the imported archives).

### 3. Optional fail-fast markers (`BUILDMASTER_FAIL_FAST`)

```bash
export BUILDMASTER_FAIL_FAST=1
# truthy: 1, ON, TRUE, YES (case-insensitive)
# or: cmake -DBUILDMASTER_FAIL_FAST=ON ...
```

| Value | Behaviour |
|-------|-----------|
| **ON** | On the first failed build/install stage, write markers under `${BUILDMASTER_BINDIR}/markers/`. Later stages that still run see the global marker and print `Skipped <component title>`, then fail. Env runners also refuse to run if the global marker exists (`Skipped due to previous errors`). |
| **OFF** (default) | **No markers are written.** Stages still fail on their own exit codes; independent components can continue. Prefer this when **warming ccache/sccache** so one broken bundle does not stop the rest. |

Markers (only when fail-fast is ON and a stage fails):

```text
${BUILDMASTER_BINDIR}/markers/buildmaster.failed   # global halt signal
${BUILDMASTER_BINDIR}/markers/<component_id>.failed  # which component failed
```

At the **start of every parent build** (ninja, make, or `cmake --build`), the
unique target `buildmaster_build_init` removes and recreates the `markers/`
directory so markers never leak across runs. That target is created only on
the first BuildMaster bootstrap (`BUILDMASTER_CONFIGURED`), so nested
`add_subdirectory(buildmaster)` does not redefine it.

Scripts that honour fail-fast are regenerated at **configure** time: change
`BUILDMASTER_FAIL_FAST`, then re-run CMake.

### Typical CI vs cache-warming

```bash
# CI: stop early, clear logs
BUILDMASTER_FAIL_FAST=1 cmake --build build

# Populate compiler caches even if one third-party fails
unset BUILDMASTER_FAIL_FAST   # or =0
cmake --build build
```

---

## Compiler cache (ccache / sccache)

If the parent job sets:

- `CMAKE_C_COMPILER_LAUNCHER` / `CMAKE_CXX_COMPILER_LAUNCHER` (or the same
via environment), and/or
- `CCACHE_DIR` / `SCCACHE_DIR`

BuildMaster propagates them into:

- env runners (so Ninja/meson compile steps see the same cache dir)
- child CMake configures (`-DCMAKE_*_COMPILER_LAUNCHER=...`)
- Meson setup (`cmake -E env CC=… CXX=…` and cache dir vars)

Launchers are **not** folded into `CC`/`CXX` on Windows (that breaks nested
MSVC CMake). Real compilers stay in `CC`/`CXX`; launchers stay separate.

Empty launcher/dir values mean “do not inject cache” — no accidental
pollution when caching is disabled.

When warming caches, leave **`BUILDMASTER_FAIL_FAST` unset** so independent
components keep compiling after an unrelated failure.

---

## Platform notes

| Topic | Linux | Windows (MSVC) | macOS |
|-------|-------|----------------|-------|
| Env runner | `runner.sh` | `runner.bat` | same as Linux |
| Static merge | GNU `ar -M` (MRI) | `lib /OUT:` | **`libtool -static`** |
| PDB / parallel MSVC | — | `/Z7` forced for Meson | — |
| Path separators in generated CMake | forward | normalized (`TO_CMAKE_PATH` where needed) | forward |

Apple’s `ar` does not support MRI scripts (`ar -M`).  
`create_bundle_static_libraries()` selects the correct tool per platform.

---

## Recursive usage

An external CMake project may itself `add_subdirectory(buildmaster)`.  
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses the
same `BUILDMASTER_INSTALL_DIR`, marker directory, and generated script tree,
so nested projects do not fight over prefixes or double-bootstrap tools.
`buildmaster_build_init` remains a single global target.

---

## Usage modes

### Simple (recommended)

Use `create_cmake_component()`, `create_meson_component()`, or the dependant
variants. One generated fragment declares imports and wires stages.

### Advanced

Call `create_cmake_stages()` / `create_meson_stages()` yourself, then
`include()` the three scripts (configure, build, install) in the order you
need—e.g. to insert custom commands between stages, or to build multi-phase
projects (x265 12-bit → 10-bit → 8-bit) with `create_cmake_dependant_component()`.

---

## Targets and naming

| Target | Role |
|--------|------|
| `buildmaster_build_init` | Reset fail markers at the start of each parent build |
| `<component>_build` | Compile the external project |
| `<component>_install` | Install into `BUILDMASTER_INSTALL_DIR` |
| `<component>_configure` | Configure only (dependant components) |

Install rules list produced libraries as `OUTPUT`, so other targets can
`DEPENDS` on real files, not only on phony names.

Build/install stages depend on `buildmaster_build_init` when that target
exists, so markers are cleared before any stage runs.

Component ids used in target names should stay filesystem-friendly; display
titles (e.g. `VVenc (H266) codec`) may contain spaces or punctuation and are
only used in status messages (including `Skipped <title>` under fail-fast).

---

## Static library bundling

Some projects (notably multi-bitdepth x265) need several `.a` / `.lib`
archives merged into one artifact for consumers (e.g. FFmpeg).

```cmake
create_bundle_static_libraries(
	BUNDLE_SCRIPT
	"x265"
	"${LIB_8BIT};${LIB_10BIT};${LIB_12BIT}"
)
# BUNDLE_SCRIPT is a generated .sh / .bat under BUILDMASTER_SCRIPTS_COMPONENTDIR
```

| Platform | Implementation |
|----------|----------------|
| Linux | GNU `ar -M` MRI script |
| macOS | `libtool -static -o …` |
| Windows | `lib /OUT:…` |

---

## API reference (where to look)

| Area | File |
|------|------|
| Component factory (simple API) | `component/helpers.cmake` |
| Static bundler | `component/helpers.cmake` → `create_bundle_static_libraries` |
| CMake stages | `tools/cmake/helpers.cmake` |
| Meson stages | `tools/meson/helpers.cmake` |
| Git fragments | `tools/git/helpers.cmake` |
| **File download / decompress helpers** | **`tools/file/helpers.cmake`** |
| Env runners / `prepare_command` | `env/helpers.cmake` |
| Path / list / sanitize utils | `helpers.cmake` |
| Tool registration | `tools/helpers.cmake` |
| Fail-fast / markers / init | `init_vars.cmake` |

Templates (generated into the build tree):

- `tools/cmake/{configure,build,install,build_exec,install_exec}.cmake.in`
- `tools/meson/{setup,compile,install,compile_exec,install_exec}.cmake.in`
- `tools/file/{file_download,file_download_cached,file_decompress}.cmake.in`
- `component/bundler.sh.in`, `bundler_macos.sh.in`, `bundler.bat.in`
- `component/component_{static,shared}{,_dependant}.cmake.in`
- `env/runner_*.in` (including silent variants)

---

## Git helpers

Generate standalone CMake fragments and `include()` them when you need
fetch / reset / patch / branch switch during bootstrap:

```cmake
create_git_fetch(GIT_FETCH_FILE myrepo ${CMAKE_SOURCE_DIR}/thirdparty/myrepo)
include(${GIT_FETCH_FILE})

create_git_patch_file(
	GIT_PATCH_FILE
	myrepo
	${CMAKE_SOURCE_DIR}/thirdparty/myrepo
	"${CMAKE_SOURCE_DIR}/patches/a.diff;${CMAKE_SOURCE_DIR}/patches/b.diff"
)
include(${GIT_PATCH_FILE})
```

Scripts are written under `BUILDMASTER_SCRIPTS_GIT_DIR`.

---

## File download & decompress helpers

BuildMaster includes a small but powerful set of helpers for **downloading and
decompressing files** in a portable, deterministic and cache-aware way. They
are designed to be used both at configure-time and at build-time.

### Key features

- **Cache-aware downloads** (`file_download_cached`): reuses the local file when
the hash matches, avoiding unnecessary network traffic.
- **Force download with retries** (`file_download`): always downloads, verifies
the hash and automatically retries on temporary failures.
- **Portable decompression** (`file_decompress`): uses CMake’s native
`file(ARCHIVE_EXTRACT)` (works on Linux, Windows and macOS, no external tools
required).
- Consistent, early status messages so the user never wonders if the process is
stuck (`Downloading TITLE...`, `Unpacking TITLE...`).
- Strict path-traversal protection (`..` is rejected with a hard error).
- Generated scripts follow the same pattern as the Git and stage helpers
(can be `include()`d or executed with `cmake -P`).

**Important:**  
No destination path is accepted from the caller.  
The file is **always** saved under `${BUILDMASTER_DOWNLOADSDIR}/` using the
basename of the URL.

Hash strings accept `ALGORITHM=digest` (e.g. `SHA256=…`, `SHA3_256=…`).
A bare digest defaults to SHA256.

### Example

```cmake
# Recommended: cache-aware download
file_download_cached(OPUS_DL
	"https://media.xiph.org/opus/models/opus_data-${OPUS_DATA_HASH}.tar.gz"
	TITLE "Opus DNN data"
	EXPECTED_HASH "SHA256=${OPUS_DATA_HASH}"
)
include(${OPUS_DL})          # runs at configure-time

# The file is now available at:
# ${BUILDMASTER_DOWNLOADSDIR}/opus_data-<hash>.tar.gz

# Decompress
file_decompress(OPUS_UNPACK
	"${BUILDMASTER_DOWNLOADSDIR}/opus_data-${OPUS_DATA_HASH}.tar.gz"
	"${CMAKE_BINARY_DIR}/src/opus"
	TITLE "Opus DNN data"
)
include(${OPUS_UNPACK})
```

Typical output:

```
Downloading Opus DNN data... (cached) OK
Unpacking Opus DNN data... OK
```

---

## Examples

### CMake component

```cmake
add_subdirectory(thirdparty/buildmaster)
include(thirdparty/buildmaster/helpers.cmake)

set(options "-DENABLE_FEATURE=ON")
create_cmake_component(
	LIB_CREATE_FILE
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"${options}"
	shared
	"mylib"
)
include(${LIB_CREATE_FILE})
```

### Meson component

```cmake
create_meson_component(
	OUT
	opus
	"Opus"
	${CMAKE_SOURCE_DIR}/thirdparty/opus
	${CMAKE_BINARY_DIR}/thirdparty/opus_build
	"-Ddefault_library=shared"
	shared
	"opus"
)
include(${OUT})
```

### Dependent component

Configure/build of `liba` waits on `libb`’s install stage:

```cmake
create_cmake_component(B_FILE libb "LibB" ... shared "libb")
include(${B_FILE})

create_cmake_dependant_component(
	A_FILE
	liba
	"LibA"
	${CMAKE_SOURCE_DIR}/thirdparty/liba
	${CMAKE_BINARY_DIR}/thirdparty/liba_build
	"${options}"
	shared
	"liba"
	"libb_install"
)
include(${A_FILE})
```

### Explicit stages

```cmake
create_cmake_stages(
	cfg_script build_script install_script
	mylib "My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"-DENABLE_FEATURE=ON"
	shared
	"${BUILDMASTER_INSTALL_LIBDIR}/libmylib.so"
)
include(${cfg_script})
include(${build_script})
include(${install_script})
```

### Merge static archives (e.g. after multi-phase x265)

```cmake
library_import_static_hint(X265_LIBRARY "x265")
create_bundle_static_libraries(
	BUNDLE_X265
	"x265"
	"${X265_LIBRARY_8};${X265_LIBRARY_10};${X265_LIBRARY_12}"
)
add_custom_command(TARGET x265_install POST_BUILD
	COMMAND ${ENV_CMAKE_SILENT_COMMAND} -E remove "${X265_LIBRARY}"
	COMMAND ${BUNDLE_X265}
	COMMENT "Repacking x265 static libraries"
)
```

### Fail-fast in CI

```bash
export BUILDMASTER_FAIL_FAST=1
cmake -S . -B build -G Ninja
cmake --build build
# On first stage failure: markers written, later stages may print
# "Skipped <component>", parent build exits non-zero
```

---

## License

MIT. See [`LICENSE`](LICENSE) for the full text.
