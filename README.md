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
propagation, portable static-library bundling, **header-only components**,
**optional per-component toolchains**, and **controlled failure propagation**
across the dependency graph.

## Table of contents

- [Overview](#overview)
- [Motivation](#motivation)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [Output verbosity and diagnostics](#output-verbosity-and-diagnostics)
- [Fail-fast and stage failure propagation](#fail-fast-and-stage-failure-propagation)
- [Compiler cache (ccache / sccache)](#compiler-cache-ccache--sccache)
- [Per-component toolchains](#per-component-toolchains)
- [Platform notes](#platform-notes)
- [Recursive usage](#recursive-usage)
- [Usage modes](#usage-modes)
- [Targets and naming](#targets-and-naming)
- [Header-only components](#header-only-components)
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
- create deterministic **IMPORTED** targets (or **INTERFACE**-only targets
  for header-only packages)
- attach `POST_BUILD` / install hooks to real stage targets
- share one install prefix and environment across a dependency tree
- fail the parent when a required external stage fails (headers/libs never
“half present”)
- optionally build a single component with a **different toolchain** than the
  parent job (for example Crypto++ with MSVC while the rest of the tree uses
  clang-cl)

It is **not** only a source fetcher (unlike a pure `FetchContent` workflow):
it orchestrates full external builds. Sources may still be managed with the
included Git helpers, the file download helpers, or any other means.

Typical use cases: bundling FFmpeg and its plugins, multi-bitdepth codecs
(e.g. x265 8/10/12-bit), Vulkan headers + loader graphs, and mixed CMake +
Meson dependency trees on Linux, Windows, and macOS (including Apple Silicon).

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

Some third-party projects also refuse or misbehave under a given compiler
(for example Crypto++’s hard error when both `_MSC_VER` and `__clang__` are
defined). BuildMaster can pin **only that component** to another toolchain
without changing the parent job.

BuildMaster fills those gaps with **configure-time** generated scripts,
explicit targets, env runners, optional **per-component toolchains**, and
optional **fail-fast** markers so a stage failure is visible and can stop
subsequent work:

```text
<component>_configure
<component>_build
<component>_install
```

---

## Comparison

| Capability                              | FetchContent | ExternalProject_Add | BuildMaster          |
|-----------------------------------------|:------------:|:-------------------:|:--------------------:|
| Fetch / manage sources                  | Yes          | Yes                 | Yes (Git helpers)    |
| **Intelligent / cacheable downloads**   | Partial      | Manual              | **Yes (built-in)**   |
| Configure external project              | N/A          | Build time          | **Configure stage**  |
| Inspect artifacts before main build     | No           | No                  | **Yes**              |
| Explicit `_configure` / `_build` / `_install` | No     | No                  | **Yes**              |
| Attach post-steps to those targets      | No           | Limited             | **Yes**              |
| Native Meson stages                     | No           | Manual              | **Yes**              |
| Shared install + env propagation        | No           | Manual              | **Yes**              |
| Compiler cache into child builds        | Manual       | Manual              | **Yes**              |
| **Per-component toolchain override**    | No           | Manual              | **Yes (optional)**   |
| Portable static archive merge           | No           | Manual              | **Yes**              |
| **Header-only components (INTERFACE)**  | Manual       | Manual              | **Yes**              |
| Safe recursive nesting                  | Fragile      | Fragile             | **Designed for it**  |
| **Fail-fast / skip after stage failure**| No           | Manual              | **Yes (optional)**   |
| **INTERFACE deps on `_install`**        | No           | Manual              | **Yes**              |
| **Git reset + reconfigure (`buildmaster_clean`)** | No   | Manual              | **Yes (optional)**   |
| **Per-repo post-install git reset**     | No           | Manual              | **Yes**              |

---

## Design goals

- Deterministic **stage-based** orchestration (configure / build / install)
- Coherent environment (`PATH`, `PKG_CONFIG_PATH`, `LIB`, `INCLUDE`,
compilers, flags, optional ccache/sccache)
- **Linux / Windows / macOS** (x86_64 and arm64)
- CMake and Meson behind the same component API
- First-class **header-only** packages (no fake `.a` / empty OUTPUT lists)
- Optional **per-component toolchains** (isolated runners; never rewrite the
  parent toolchain)
- Generated scripts that are inspectable and CI-friendly
- One initialization, one install root, even in deep dependency trees
- Quiet default logs with **full diagnostics on failure**, optional
**DEBUG** (all stages) and **VERBOSE** (compile stages only)
- Intelligent, cacheable and portable file download / decompression
- Predictable failure behaviour: a broken required component must fail the
parent graph, not surface as a missing include later
- Git helpers bound to a **component id**: ops run at the start of that
component’s **configure** stage; `buildmaster_clean` resets sources and
**invalidates configure** so the next build re-applies patches; install
resets **only that repo** afterward

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
`Configuring …` / `Compiling …` / `Installing …`) so large dependency graphs
stay readable. “Silent” runners suppress underlying tool stdout/stderr
**on success**.

### On failure

Silent runners capture output into a unique temporary file. If the child
command exits non-zero, the log is written to **stderr** (then the temp file
is removed). That way:

- `execute_process(... ERROR_VARIABLE ...)` still receives the full log
- CI consoles show configure/build failures without enabling full verbosity
- parallel jobs do not clash on log paths (`mktemp` / unique names under `%TEMP%`)

Stage exec scripts (`*_configure_exec` / `*_build_exec` / `*_install_exec`
and Meson equivalents) also report a clear fatal error when the underlying
tool fails.

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
| Git helpers | Unchanged |

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

Scripts are generated at **parent configure** time: change
`BUILDMASTER_VERBOSE` or `BUILDMASTER_DEBUG`, then re-run CMake so stage
scripts are regenerated.

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

Component templates (`component_static*.cmake.in`, `component_shared*.cmake.in`,
`component_headers*.cmake.in`) attach:

```text
add_dependencies(<INTERFACE> <component>_install)
```

Library modes also attach the same dependency to each **IMPORTED** archive.
So a parent that does:

```cmake
target_link_libraries(MyLib PRIVATE SomeBundledComponent)
```

waits for a **successful** install before treating the component as ready
(headers under `BUILDMASTER_INSTALL_INCLUDEDIR` and, for library modes, the
imported archives).

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

Scripts that honour fail-fast are regenerated at **parent configure** time:
change `BUILDMASTER_FAIL_FAST`, then re-run CMake.

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

## Per-component toolchains

By default every component inherits the **parent job** compilers, linker and
archiver (same as before).

An optional trailing **`TOOLCHAIN`** argument on the component factory
functions selects a named profile for **that component only**:

| Name | Typical drivers | Linker policy |
|------|-----------------|---------------|
| `gcc` | `gcc` / `g++` | System default (LLD not forced) |
| `clang` | `clang` / `clang++` | **LLD required on Linux**; not forced on **macOS** |
| `clang-cl` | `clang-cl` | **LLD** (`lld-link`) + `llvm-lib` (Windows only) |
| `msvc` | `cl` | **`link.exe`** + `lib.exe` (Windows only) |

### Rules

- **Optional and backward compatible** — omit the argument and behaviour is
  unchanged.
- **Override is complete for that component** — configure, build and install
  all use the same profile.
- **Isolated** — does not rewrite the parent toolchain file or global env
  runner; component-local runners (normal + silent) are generated instead.
  When a component `TOOLCHAIN` is set, nested CMake **does not** load the
  parent `BUILDMASTER_TOOLCHAIN_FILE` (avoids `FORCE` of parent `CMAKE_AR` /
  linker); compilers and binutils are passed explicitly from the profile.
- **Unknown names** fail at configure with a list of known toolchains.
- **Platform guards** — `msvc` / `clang-cl` only on Windows; `gcc` / `clang`
  are not accepted as component toolchains on Windows.
- **Linker flags** are not wiped: known LLD / Clang-LTO tokens are stripped
  when targeting `msvc`; other flags are kept.
- **IPO / LTO** is never turned on by the profile. If the parent already had
  IPO enabled, nested stages keep a coherent setting; if not, it stays off.

### Where it is accepted

Trailing optional arguments (after the existing optional indent level):

| Function | Optional trailing args |
|----------|------------------------|
| `create_cmake_component` / `create_meson_component` | `[indent] [toolchain]` |
| `create_cmake_dependant_component` / `create_meson_dependant_component` | `[indent] [toolchain]` |
| `create_cmake_headers_component` / `create_meson_headers_component` | `[indent] [toolchain]` |
| `create_cmake_headers_dependant_component` / `create_meson_headers_dependant_component` | `[indent] [toolchain]` |
| `create_cmake_stages` / `create_meson_stages` | `[indent] [toolchain] [configure_via_target]` |

`configure_via_target` is only meaningful on the **atomic stage** API. Pass
`"1"` when configure will run under a dependant-style custom target (suppress
the hierarchical `message(STATUS "Configuring …")`; the target `COMMENT` is
enough). Pass `"0"` or omit it for normal configure-time `include()` of the
configure script. The simple `create_*_component` / `create_*_dependant_*`
helpers set this automatically.

### Example (MSVC only for one library)

```cmake
create_cmake_component(
	CRYPTOPP_FILE
	CryptoPP
	"Crypto++ Library"
	${CRYPTOPP_SRC}
	${CRYPTOPP_BUILD}
	"${CRYPTOPP_OPTIONS}"
	static
	"cryptopp"
	0          # indent (optional, same as before)
	msvc       # TOOLCHAIN (optional)
)
include(${CRYPTOPP_FILE})
```

Profiles live under `toolchain/profiles/`; validation and flag cleanup live
in `toolchain/helpers.cmake`.

---

## Platform notes

| Topic | Linux | Windows (MSVC / clang-cl) | macOS |
|-------|-------|---------------------------|-------|
| Env runner | `runner.sh` | `runner.bat` | same as Linux |
| Static merge | GNU `ar -M` (MRI) | `lib /OUT:` | **`libtool -static`** |
| PDB / parallel MSVC | — | `/Z7` forced for Meson | — |
| Path separators in generated CMake | forward | normalized (`TO_CMAKE_PATH` where needed) | forward |
| Component `TOOLCHAIN clang` | LLD required | not used (use `clang-cl`) | LLD **not** forced |
| Component `TOOLCHAIN msvc` / `clang-cl` | invalid | supported | invalid |

Apple’s `ar` does not support MRI scripts (`ar -M`).  
`create_bundle_static_libraries()` selects the correct tool per platform.

---

## Recursive usage

An external CMake project may itself `add_subdirectory(buildmaster)`.  
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses the
same `BUILDMASTER_INSTALL_DIR`, marker directory, and generated script tree,
so nested projects do not fight over prefixes or double-bootstrap tools.
`buildmaster_build_init` remains a single global target.

Per-component toolchain overrides remain local to the component that requested
them; they are not promoted into the shared toolchain file for nested
bootstraps.

---

## Usage modes

### Simple (recommended)

Use:

| Function | Role |
|----------|------|
| `create_cmake_component()` / `create_meson_component()` | Static or shared libraries |
| `create_cmake_dependant_component()` / `create_meson_dependant_component()` | Same, ordered after another `*_install` |
| `create_cmake_headers_component()` / `create_meson_headers_component()` | Header-only packages |
| `create_cmake_headers_dependant_component()` / `create_meson_headers_dependant_component()` | Header-only, ordered after another `*_install` |

One generated fragment declares the INTERFACE (and IMPORTED libs when
applicable) and wires stages. Optional trailing **`TOOLCHAIN`** selects a
named profile for that component only.

### Advanced

Call `create_cmake_stages()` / `create_meson_stages()` yourself, then
`include()` the three scripts (configure, build, install) in the order you
need—e.g. to insert custom commands between stages, or to build multi-phase
projects (x265 12-bit → 10-bit → 8-bit) with dependant components.
`_library_mode` may be `static`, `shared`, or `headers`.

Optional trailing arguments on the stage helpers:

```text
[indent_level] [toolchain] [configure_via_target]
```

- **`toolchain`** — same named profiles as the simple API (`gcc`, `clang`,
  `clang-cl`, `msvc`), or empty to inherit the parent job.
- **`configure_via_target`** — `"1"` if you will drive configure through a
  custom target (dependant-style); `"0"` or omit when the configure script is
  `include()`d at parent configure time.

`TOOLCHAIN` and `configure_via_target` are independent: you can override the
toolchain for a component that still configures at parent configure time.

---

## Targets and naming

| Target | Role |
|--------|------|
| `buildmaster_build_init` | Reset fail markers at the start of each parent build |
| `buildmaster_clean` | Reset registered git repos **and** invalidate their component configure stages |
| `<component>_configure` | Git pre-ops (if any) + nested CMake/Meson configure |
| `<component>_build` | Compile (depends on `<component>_configure`) |
| `<component>_install` | Install into `BUILDMASTER_INSTALL_DIR` |

Install rules list produced libraries (or a **headers stamp file**) as
`OUTPUT`, so other targets can `DEPENDS` on real files, not only on phony
names.

Build/install stages depend on `buildmaster_build_init` when that target
exists, so markers are cleared before any stage runs.

Component ids used in target names should stay filesystem-friendly; display
titles (e.g. `VVenc (H266) codec`) may contain spaces or punctuation and are
only used in status messages (including `Skipped <title>` under fail-fast).

---

## Header-only components

Some third-party projects install **only headers** (and CMake package files),
with no `.a` / `.lib` / `.so`. Using `create_cmake_component` with an empty
subcomponent list used to produce an empty `OUTPUT` list and break under
modern CMake (policy CMP0175).

BuildMaster models this as a dedicated **`headers`** library mode:

| Stage | Behaviour |
|-------|-----------|
| configure | Nested CMake or Meson setup (same as library components) |
| build | Still runs (`cmake --build` / `meson compile`). Header-only trees are typically no-ops or dummy targets; the stage remains for a uniform graph |
| install | `cmake --install` / `meson install` into `BUILDMASTER_INSTALL_DIR` |
| OUTPUT artifact | Stamp file: `${builddir}/.buildmaster_headers_installed` (written by install if missing) |
| CMake target | `add_library(<component> INTERFACE)` + `target_include_directories(... SYSTEM INTERFACE "${BUILDMASTER_INSTALL_INCLUDEDIR}")` + dependency on `<component>_install` |
| **No** | `IMPORTED` static/shared libraries |

### API

```cmake
create_cmake_headers_component(
	OUT_FILE
	vulkan-headers
	"Vulkan-Headers"
	${HEADERS_SRC}
	${HEADERS_BUILD}
	"${HEADERS_OPTIONS}"
	# optional indent level
	# optional TOOLCHAIN
)

create_cmake_headers_dependant_component(
	OUT_FILE
	...
	"other_component_install"   # wait on this install target
)

# Meson equivalents:
#   create_meson_headers_component(...)
#   create_meson_headers_dependant_component(...)
```

Signatures mirror the library helpers but **omit** `_library_mode` and
`_subcomponents` (always `headers`, no artifact base names).

### Example (Vulkan-Headers)

```cmake
set(VULKAN_HEADERS_OPTIONS
	"-DVULKAN_HEADERS_ENABLE_MODULE=OFF"
	"-DVULKAN_HEADERS_ENABLE_TESTS=OFF"
)
create_cmake_headers_component(
	VULKAN_HEADERS_FILE
	"vulkan-headers"
	"Vulkan-Headers"
	"${CMAKE_CURRENT_LIST_DIR}/src"
	"${CMAKE_CURRENT_BINARY_DIR}/build"
	"${VULKAN_HEADERS_OPTIONS}"
	${PLUGIN_LEVEL}
)
include("${VULKAN_HEADERS_FILE}")

# Loader still uses a normal library component, ordered after headers:
create_cmake_dependant_component(
	VULKAN_LOADER_FILE
	"vulkan-loader"
	"Vulkan-Loader"
	...
	static
	"vulkan"
	"vulkan-headers_install"
)
include("${VULKAN_LOADER_FILE}")
```

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
| Header-only wrappers | `component/helpers.cmake` → `create_*_headers_*` |
| Static bundler | `component/helpers.cmake` → `create_bundle_static_libraries` |
| CMake stages | `tools/cmake/helpers.cmake` |
| Meson stages | `tools/meson/helpers.cmake` |
| **Toolchain profiles / validation** | **`toolchain/helpers.cmake`**, **`toolchain/profiles/`** |
| Git fragments | `tools/git/helpers.cmake` |
| **File download / decompress helpers** | **`tools/file/helpers.cmake`** |
| Env runners / `prepare_command` / component runners | `env/helpers.cmake` |
| Path / list / sanitize utils | `helpers.cmake` |
| Tool registration | `tools/helpers.cmake` |
| Fail-fast / markers / init | `init_vars.cmake` |

Templates (generated into the build tree):

- `tools/cmake/{configure,build,install,build_exec,install_exec}.cmake.in`
- `tools/meson/{setup,compile,install,compile_exec,install_exec}.cmake.in`
- `tools/file/{file_download,file_download_cached,file_decompress}.cmake.in`
- `component/bundler.sh.in`, `bundler_macos.sh.in`, `bundler.bat.in`
- `component/component_{static,shared,headers}{,_dependant}.cmake.in`
- `env/runner_*.in` (including silent variants; per-component copies when `TOOLCHAIN` is set)
- `toolchain/profiles/{gcc,clang,clang-cl,msvc}.cmake`

---

## Git helpers

Git operations are bound to a **component id** (the same id used in
`create_cmake_component` / `create_meson_component` / headers helpers,
e.g. `vpx`).

```cmake
create_git_reset_file(
	VPX_RESET_REPO
	vpx                    # component id → vpx_configure / vpx_build / …
	"VPX reset"
	${VPX_SRC_DIR}
)
create_git_patch_file(
	VPX_PATCH_REPO
	vpx
	"VPX patch"
	${VPX_SRC_DIR}
	"${CMAKE_CURRENT_LIST_DIR}/0001-….patch"
)
# Optional: include() at parent configure for early patching.
# The component configure stage always re-runs registered git scripts when it runs.
create_meson_component(
	OUT
	vpx
	"VPX codec"
	${VPX_SRC_DIR}
	${VPX_BUILD_DIR}
	"${VPX_OPTIONS}"
	shared
	"vpx"
)
include(${OUT})
```

| Function | Role |
|----------|------|
| `create_git_reset_file(out, component_id, title, repo)` | `git reset --hard` + `git clean -fd` |
| `create_git_patch_file(out, component_id, title, repo, patches)` | `git apply` |
| `create_git_fetch(out, component_id, title, repo)` | `git fetch` |
| `create_git_switch_branch(out, component_id, title, repo, branch)` | branch switch |

Scripts are written under `BUILDMASTER_SCRIPTS_GIT_DIR`.

**Order:** call `create_git_*` **before** `create_*_component` /
`create_*_stages` for that component id so registration is visible when
stages are generated.

### When git runs

Registered scripts run at the **start of `<component>_configure`**
(nested CMake/Meson configure), in registration order. That stage is a real
build target; `<component>_build` depends on it.

Typical sequence after a clean rebuild of one component:

```text
vpx_configure
  → git reset / patch / …
  → meson setup or cmake -S/-B (if not already configured)
vpx_build
vpx_install
  → optional post-install git reset (this repo only)
```

### Post-install reset (automatic, per repo)

If a component was registered via `create_git_*`, its `*_install` target
runs after a successful install:

- `git reset --hard`
- `git clean -fd`

from the **git toplevel** of that source tree only (subdirectory srcdirs such
as `libvmaf/` still resolve to the repo root).

No manual `POST_BUILD` reset hooks are required in consumer projects.

### Aggregate clean: `buildmaster_clean`

When `BUILDMASTER_CLEAN_RESET_REPOS` is enabled (**default ON**), every
component that used `create_git_*` contributes a mini-target under:

```bash
cmake --build build --target buildmaster_clean
```

For each registered component that target:

1. Resets the git working tree (`reset --hard` + `clean -fd`)
2. **Invalidates configure** for that component only (removes Meson
   `build.ninja` / `meson-private`, or CMake `CMakeCache.txt` / `build.ninja`
   under that component’s build directory)

The next `cmake --build` / `ninja` / `make` therefore re-enters
`<component>_configure`, which re-applies git ops and re-runs nested setup.

This is **not** wired to the generator’s native `clean` target (unreliable
with Ninja).

| Value | Behaviour |
|-------|-----------|
| **ON** (default) | `buildmaster_clean` resets repos + invalidates configure |
| **OFF** | No aggregate git clean targets |

```bash
# Disable
export BUILDMASTER_CLEAN_RESET_REPOS=0
# or OFF / FALSE / NO

# Enable (default)
export BUILDMASTER_CLEAN_RESET_REPOS=1
```

Propagated to nested BuildMaster instances via the toolchain file. Change the
variable and re-run CMake so targets/scripts are regenerated.

Typical workflow:

```bash
cmake --build build --target clean              # build-tree artifacts only
cmake --build build --target buildmaster_clean  # git sources + force reconfigure
cmake --build build                             # configure → git → setup → build
```

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

### Header-only CMake component

```cmake
create_cmake_headers_component(
	HEADERS_FILE
	vulkan-headers
	"Vulkan-Headers"
	${CMAKE_SOURCE_DIR}/thirdparty/vulkan-headers
	${CMAKE_BINARY_DIR}/thirdparty/vulkan-headers_build
	"-DVULKAN_HEADERS_ENABLE_TESTS=OFF"
)
include(${HEADERS_FILE})
# Target "vulkan-headers" is INTERFACE; depends on vulkan-headers_install
```

### Meson component with git patch

```cmake
create_git_reset_file(RESET_OUT vpx "VPX reset" ${VPX_SRC_DIR})
create_git_patch_file(PATCH_OUT vpx "VPX patch" ${VPX_SRC_DIR} "${VPX_PATCH}")
create_meson_component(
	OUT
	vpx
	"VPX codec"
	${VPX_SRC_DIR}
	${VPX_BUILD_DIR}
	"${VPX_OPTIONS}"
	shared
	"vpx"
)
include(${OUT})
# vpx_configure runs git scripts then meson setup
# vpx_install resets only the VPX repo afterward
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

### Component with an explicit toolchain

```cmake
# Parent job may be clang-cl; this component alone uses MSVC
create_cmake_component(
	CRYPTOPP_FILE
	CryptoPP
	"Crypto++ Library"
	${CRYPTOPP_SRC}
	${CRYPTOPP_BUILD}
	"${CRYPTOPP_OPTIONS}"
	static
	"cryptopp"
	0
	msvc
)
include(${CRYPTOPP_FILE})
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
	# optional: indent_level
	# optional: toolchain (e.g. msvc)
	# optional: configure_via_target ("1" = dependant-style custom target)
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

### Git clean then rebuild

```bash
cmake --build build --target buildmaster_clean
cmake --build build
# configure stages re-run → git ops → nested setup → build
```

---

## License

MIT. See [`LICENSE`](LICENSE) for the full text.
