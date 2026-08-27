# StormByte BuildMaster

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Meson](https://img.shields.io/badge/Meson-supported-orange)
![Ninja](https://img.shields.io/badge/Ninja-supported-0f4c81)
![Status](https://img.shields.io/badge/status-active-success)

A **declarative CMake DSL** that turns external **CMake** and **Meson**
projects into first-class pieces of a parent tree: register components and
edges in any order, one shared install prefix, header-only components,
optional per-component toolchains, portable archive rename, optional
whole-archive static linking, and failure behaviour that does not leave the
parent compiling against a half-empty prefix.

## Table of contents

- [What it is](#what-it-is)
- [Why it exists](#why-it-exists)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [Declarative model](#declarative-model)
- [How a component works](#how-a-component-works)
- [Dependencies and links](#dependencies-and-links)
- [Prerequisites](#prerequisites)
- [Component options string](#component-options-string)
- [Whole-archive linking (WHOLE)](#whole-archive-linking-whole)
- [Subcomponent specs and library paths](#subcomponent-specs-and-library-paths)
- [Header-only components](#header-only-components)
- [Per-component toolchains](#per-component-toolchains)
- [Recursive usage](#recursive-usage)
- [Verbosity and diagnostics](#verbosity-and-diagnostics)
- [Fail-fast](#fail-fast)
- [Compiler cache](#compiler-cache)
- [Platform notes](#platform-notes)
- [Git helpers](#git-helpers)
- [File download and decompress](#file-download-and-decompress)
- [API map](#api-map)
- [Self-tests](#self-tests)
- [License](#license)

---

## What it is

BuildMaster registers **components** and **graph edges** while the parent is
still configuring. Materialization (stage scripts, IMPORTED targets, link
lines) runs **once** at the end of the parent `CMAKE_SOURCE_DIR` scope
(internal deferred finalize). You do not `include()` generated fragments.

The parent can:

- declare components and dependencies in **any order**
- create deterministic **IMPORTED** (or **INTERFACE**) targets
- share one install prefix and environment across a dependency tree
- fail the parent when a required external stage fails
- optionally build **one** component with a different toolchain than the job
- attach downloads, unpack steps, or custom work via **prerequisite** targets
- mark static components so consumers pull **entire** archives (`WHOLE`)

Sources can come from the Git helpers, file helpers, a submodule, or anything
else that produces a source tree.

Typical uses: bundled third-party libraries, multi-variant builds of the same
tree, header-only SDK graphs, mixed CMake + Meson graphs on Linux, Windows,
and macOS (including Apple Silicon).

---

## Why it exists

`ExternalProject_Add` configures and builds **at build time**. Too late to
branch on results, generate import targets from real paths, or enforce one
install layout with a clear graph.

`FetchContent` brings sources in but does not orchestrate CMake **and** Meson
with the same model.

Meson does not inherit `PKG_CONFIG_PATH`, prefix, compilers, flags, or cache
launchers the way nested CMake does. Without a control layer, nested Meson
often misses previous `.pc` files or uses the wrong toolchain.

A failed compile can still leave other components installing while the parent
compiles against missing headers.

Some upstreams misbehave under one compiler. BuildMaster can pin **only that
component** to another toolchain.

Static plugin-style archives (e.g. FFmpeg + codecs) often need
**whole-archive** linkage so registration objects are not dropped by the
linker. BuildMaster can attach that policy to a component’s INTERFACE.

Generated stages look like this:

```text
<component>_configure
<component>_build
<component>_install
```

---

## Comparison

| Capability | FetchContent | ExternalProject_Add | BuildMaster |
|------------|:------------:|:-------------------:|:-----------:|
| Fetch / manage sources | Yes | Yes | Yes (Git helpers) |
| Cacheable downloads | Partial | Manual | **Built-in** |
| Declarative graph (order-independent) | No | No | **Yes** |
| Configure external project | N/A | Build time | **Eager or deferred** |
| Inspect artifacts before main build | No | No | **When eager** |
| Explicit `_configure` / `_build` / `_install` | No | No | **Yes** |
| Attach post-steps to those targets | No | Limited | **Yes** |
| Native Meson stages | No | Manual | **Yes** |
| Shared install + env propagation | No | Manual | **Yes** |
| Compiler cache into child builds | Manual | Manual | **Yes** |
| Per-component toolchain | No | Manual | **Optional** |
| Header-only INTERFACE components | Manual | Manual | **Yes** |
| Path-qualified subcomponents (`subdir/name`) | No | Manual | **Yes** |
| Whole-archive static link on INTERFACE | Manual | Manual | **Optional (`WHOLE`)** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |
| Fail-fast after a stage failure | No | Manual | **Optional** |
| INTERFACE depends on `_install` | No | Manual | **Yes** |
| Git reset + reconfigure (`buildmaster_clean`) | No | Manual | **Optional** |
| Per-repo post-install git reset | No | Manual | **Yes** |

---

## Design goals

- Declarative registration; materialize once (deferred)
- Stage-based orchestration (configure / build / install)
- One environment: `PATH`, `PKG_CONFIG_PATH`, `LIB`, `INCLUDE`, compilers,
  flags, optional ccache/sccache
- Linux / Windows / macOS (x86_64 and arm64)
- CMake and Meson behind the same component API
- Header-only packages without fake archives or empty `OUTPUT` lists
- Optional per-component toolchains that never rewrite the parent toolchain
- One initialization, one install root, even in nested trees
- Quiet logs by default, full dump on failure
- Predictable failure: a broken required component fails the parent graph
- Git ops bound to a component id (configure-time, then optional reset)
- File helpers as build targets wired through the same dependency graph
- Extensible options via one trailing `KEY=value;…` string
- Library artifacts that can live in a **subdir** of the shared libdir
- Optional whole-archive policy per static component (`WHOLE`)

---

## Quick start

```cmake
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")  # optional

add_subdirectory(path/to/buildmaster)
include(path/to/buildmaster/helpers.cmake)

set(_opts "-DENABLE_FOO=ON")
create_cmake_component(
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"${_opts}"
	shared
	"mylib"
)

# Optional edges (order relative to create_* does not matter):
# component_dependency(mylib other)
# component_link(mylib "extra_static")

target_link_libraries(MyApp PRIVATE mylib)
```

There is no out-variable and no `include()` of a generated fragment. Stage
targets and IMPORTED libraries are created when components are materialized
(end of the parent `CMAKE_SOURCE_DIR` scope).

Options go in a **single** trailing string:

```cmake
create_cmake_component(
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"${_opts}"
	shared
	"mylib"
	"INDENT=2;TOOLCHAIN=clang-cl;RENAME"
)
```

---

## Declarative model

1. **Register** components with `create_cmake_component` / `create_meson_component`
   (or the headers variants / low-level `create_component`).
2. **Connect** them with `component_dependency` and/or `component_link`
   (declaration order does not matter).
3. **Optional** work before a component: `component_prerequisite`,
   `file_download` / `file_download_cached` / `file_decompress`, or
   configure-time `create_git_*`.
4. At the end of `CMAKE_SOURCE_DIR`, BuildMaster **materializes** stages and
   applies links. Consumers never call finalize (it is internal).

| Configure timing | When |
|------------------|------|
| **Eager** | Component is not the `source` of any `component_dependency` → nested configure during parent configure |
| **Deferred** | Component is the `source` of at least one dependency → nested configure at build time under `<id>_configure` |

---

## How a component works

| Target | Role |
|--------|------|
| `<component>` | `INTERFACE`. Depends on `<component>_install`. This is what you link. |
| `<component>_configure` | Nested CMake/Meson configure |
| `<component>_build` | Compile |
| `<component>_install` | Install into `BUILDMASTER_INSTALL_DIR` |
| produced libs | `STATIC` / `SHARED` **IMPORTED** archives under the install prefix |

Library-mode install lists archive paths as `OUTPUT` so other targets (and
Ninja) can depend on real files. Library specs introduced via
`component_link` may be added to that contract when they are not already
graph nodes.

Component **ids** should be filesystem-friendly (they become target and
script names). Display **titles** may contain spaces; they only appear in
status lines.

---

## Dependencies and links

### `component_dependency(source, dest)`

Order-only edge. At materialize time, `dest` resolves as (first match):

1. Registered component id → `<id>_install`
2. Name matching `*_install` / `*_configure` / `*_build`
3. Existing CMake target (e.g. `component_prerequisite`, `file_*` target)

Otherwise materialization fails with **FATAL_ERROR**.

### `component_link(source, dest)`

Records a link from the component `INTERFACE`. When `dest` is a **graph
node** (registered component, stage name, or existing target), it also
records `component_dependency`. Pure library specs do **not** get an
automatic dependency edge.

| `dest` | Effect |
|--------|--------|
| Registered component | Link produced IMPORTED libs + that component’s INTERFACE; order on its install. If the dest has `WHOLE`, the INTERFACE already carries whole-archive items (do not also link plain IMPORTED names). |
| Existing target | `target_link_libraries(… INTERFACE …)` |
| Existing non-directory path | Link that file |
| Spec `name` or `subdir/name` | IMPORTED under install libdir; may extend install `OUTPUT` on **source** |

```cmake
create_cmake_component(libb … static "libb")
create_cmake_component(liba … static "liba")
component_dependency(liba libb)
component_link(liba libb)

target_link_libraries(MyApp PRIVATE liba)
```

Host application targets are **not** BuildMaster graph nodes: link them with
ordinary `target_link_libraries(MyApp PRIVATE <component_id>)`.

---

## Prerequisites

```cmake
component_prerequisite(my_prep
	COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/prep.stamp"
	COMMENT "Prepare something"
)
component_dependency(mylib my_prep)
```

Optional keywords: `SCRIPT` (implies `cmake -P` if `COMMAND` is omitted),
`WORKING_DIRECTORY`, `DEPENDS`. The target is created **immediately** so it
can be used as a dependency destination.

Prefer `file_download*` / `file_decompress` when they fit the job.

---

## Component options string

Every `create_*_component` / headers wrapper accepts **at most one** optional
trailing argument:

```text
"KEY=value;KEY2=value with spaces"
```

| Rule | Detail |
|------|--------|
| Pair separator | `;` |
| Key / value | Only the **first** `=` in a pair |
| Keys | Case-insensitive, stored **UPPERCASE** |
| Values | May contain spaces and extra `=` |
| `;` in a value | Not allowed |
| Flag keys | May omit `=` (see below) |
| Unknown key | **WARNING**, ignored |
| Extra positional args | **FATAL_ERROR** |

| Key | Meaning |
|-----|---------|
| `INDENT` / `INDENT_LEVEL` | Tabs in hierarchical `STATUS` lines (non-negative integer) |
| `TOOLCHAIN` | Profile name (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `RENAME` | Normalize variant install basenames to the produced name (default **ON** for library modes). Flag form: `RENAME` ≡ `RENAME=ON` |
| `WHOLE` | Link all produced **static** archives of this component with whole-archive semantics on its INTERFACE (default **OFF**). Flag form: `WHOLE` ≡ `WHOLE=ON`. On `shared` / `headers`: **WARNING**, ignored |

Flag-style keys are listed in `BUILDMASTER_COMPONENT_OPTION_FLAGS` (`RENAME`,
`WHOLE`, …). `LINK_EXTRA` is removed; use `component_link`.

```cmake
create_cmake_component(... "mylib")
create_cmake_component(... "mylib" "INDENT=2")
create_cmake_component(... "mylib" "TOOLCHAIN=msvc;RENAME")
create_cmake_component(... "mylib" "RENAME=OFF")
create_cmake_component(... static "avutil;avcodec" "WHOLE")
```

---

## Whole-archive linking (WHOLE)

For **static** components, `WHOLE` makes the component’s `INTERFACE` link line
pull every object from its produced archives (plugin registration tables,
constructors, weakly referenced members).

| Platform | Form (one closed region per WHOLE component) |
|----------|-----------------------------------------------|
| ELF (GNU/LLVM ld) | `-Wl,--whole-archive` *paths* `-Wl,--no-whole-archive` |
| Apple | `-Wl,-force_load,path` per archive |
| MSVC | `/WHOLEARCHIVE:path` per archive |

Rules:

- **Only** the produced statics of that component sit inside the region.
- Several WHOLE components → **linear** closed regions (not nested).
- Other libraries linked beside a WHOLE component stay **outside** the region.
- Host apps: `target_link_libraries(App PRIVATE ffmpeg other)` — no need to
  hand-roll whole-archive flags when `ffmpeg` was registered with `WHOLE`.

```cmake
create_meson_component(
	ffmpeg "FFmpeg" ${SRC} ${BUILD} "${opts}" static
	"avutil;avcodec;avformat;swscale;swresample;avfilter"
	"WHOLE"
)
create_cmake_component(helper … static "helper")   # no WHOLE

target_link_libraries(MyApp PRIVATE ffmpeg helper)
# Typical ELF link shape:
#   --whole-archive libavutil.a … libavfilter.a --no-whole-archive libhelper.a
```

---

## Subcomponent specs and library paths

The produced list is the artifact name(s) used for IMPORTED targets and for
the install `OUTPUT` list.

| Spec | File (Unix static example) | IMPORTED target |
|------|----------------------------|-----------------|
| `mylib` | `${BUILDMASTER_INSTALL_LIBDIR}/libmylib.a` | `mylib` |
| `vendor/foo/foolib` | `${BUILDMASTER_INSTALL_LIBDIR}/vendor/foo/libfoolib.a` | `vendor_foo_foolib` |

- Last path component = library basename (`foolib`).
- Everything before it = subdir under `BUILDMASTER_INSTALL_LIBDIR`.
- `/` in the spec becomes `_` in the CMake target name.

Implemented by `buildmaster_parse_subcomponent()`. Paths are built with:

```cmake
library_import_static_hint(out name prefix [subdir])
library_import_hint(out name prefix [subdir])
```

`subdir` is optional and relative to `prefix` (usually
`BUILDMASTER_INSTALL_LIBDIR`).

A static archive does not pull other static archives by itself. Prefer
`component_link` for extra archives, list every required produced spec on the
component that installs them, or `WHOLE` when the entire archive must be
retained at link time.

MSVC DLLs still live under `BUILDMASTER_INSTALL_BINDIR` using the
**basename only**.

---

## Header-only components

Projects that install only headers use `headers` mode (no IMPORTED archive,
stamp `OUTPUT` under the include tree).

```cmake
create_cmake_headers_component(
	sdk-headers
	"SDK Headers"
	${HEADERS_SRC}
	${HEADERS_BUILD}
	"-DENABLE_TESTS=OFF"
)

create_cmake_component(
	sdk-loader
	"SDK Loader"
	${LOADER_SRC}
	${LOADER_BUILD}
	""
	static
	"sdkloader"
)
component_dependency(sdk-loader sdk-headers)
```

Meson: `create_meson_headers_component`. Signatures omit library mode and
produced list (always `headers`).

---

## Per-component toolchains

By default every component inherits the **job** compilers, linker, and
archiver. `TOOLCHAIN=` in the options string selects a profile for **that
component only**.

| Name | Drivers | Linker |
|------|---------|--------|
| `gcc` | `gcc` / `g++` | System default |
| `clang` | `clang` / `clang++` | LLD required on **Linux**; not forced on **macOS** |
| `clang-cl` | `clang-cl` | `lld-link` + `llvm-lib` (Windows) |
| `msvc` | `cl` | `link.exe` + `lib.exe` (Windows) |

- Omit the key (or leave it empty) to inherit the parent.
- Override covers configure, build, and install of that component.
- Isolated: no rewrite of the parent toolchain file or global env runner.
- Unknown names fail at configure and list known profiles.
- Profiles never turn IPO on by themselves.

Profiles live under `toolchain/profiles/`.

---

## Recursive usage

Nested `add_subdirectory(buildmaster)` is safe when the parent already
configured BuildMaster (`BUILDMASTER_CONFIGURED`). Nested trees share the
same install prefix and environment.

Use distinct component ids across nests. When two backends would install the
same basename, use path-qualified specs (`recursive/cmake/nestlib` vs
`recursive/meson/nestlib`).

---

## Verbosity and diagnostics

| Variable | Effect |
|----------|--------|
| `BUILDMASTER_DEBUG` | Live nested tool output |
| `BUILDMASTER_VERBOSE` | Verbose compile-only output |

Silent env runners dump captured logs on non-zero exit.

---

## Fail-fast

Optional `BUILDMASTER_FAIL_FAST` (environment or `-D`; truthy:
`1` / `ON` / `TRUE` / `YES`; default OFF).

On stage failure with fail-fast ON, BuildMaster writes failure markers and
later stages skip with a non-zero exit. The unique `buildmaster_build_init`
target resets markers at the start of every parent build.

---

## Compiler cache

Parent `CMAKE_*_COMPILER_LAUNCHER` and cache directory variables propagate
into nested CMake and Meson stages so ccache/sccache keep working across the
graph.

---

## Platform notes

- **Windows:** MSVC and clang-cl profiles; with `RENAME` on, variant basenames
  (`*-static`, debug suffixes, …) can be normalized to the produced name
  before the install contract check. `WHOLE` uses `/WHOLEARCHIVE:`.
- **Unix:** archives under `lib` or `lib64` follow `GNUInstallDirs` /
  `CMAKE_INSTALL_LIBDIR`. `WHOLE` uses `--whole-archive` / `--no-whole-archive`.
- **Apple Silicon:** Meson and CMake nests use the same shared prefix and env
  propagation as other Unix hosts. `WHOLE` uses `-force_load` per archive.

---

## Git helpers

Configure-time helpers: **no out-variable**. Each call generates a script and
`include()`s it immediately, then registers the repo for post-install reset
(and optional `buildmaster_clean`) under the given component id.

```cmake
create_git_reset_file(mycomp "reset title" "${SRC_DIR}")
create_git_patch_file(mycomp "patches" "${SRC_DIR}" "${patch_list}")
create_git_fetch(mycomp "fetch" "${SRC_DIR}")
create_git_switch_branch(mycomp "branch" "${SRC_DIR}" "main")
```

`buildmaster_git_post_install_marker_for_srcdir` resolves the generated
post-install reset script for a source directory when one was registered.

---

## File download and decompress

Build-time targets: **no out-variable**, no `include()`. The first argument is
the CMake target name. Wire them with `component_dependency`.

```cmake
file_download_cached(dnn_dl
	"https://example.com/data.tar.gz"
	TITLE "DNN data"
	EXPECTED_HASH "SHA256=…"
)

file_decompress(dnn_unpack
	"data.tar.gz"
	"${UNPACK_DIR}"
	TITLE "DNN data"
	DEPENDS dnn_dl
)

component_dependency(mylib dnn_unpack)
```

Downloads always land under `BUILDMASTER_DOWNLOADSDIR` using the URL
basename. `file_checksum_correct` remains available for explicit hash checks.

---

## API map

| Area | Commands |
|------|----------|
| Components | `create_component`, `create_cmake_component`, `create_meson_component`, `create_cmake_headers_component`, `create_meson_headers_component` |
| Graph | `component_dependency`, `component_link`, `component_prerequisite` |
| File | `file_download`, `file_download_cached`, `file_decompress`, `file_checksum_correct` |
| Git | `create_git_reset_file`, `create_git_patch_file`, `create_git_fetch`, `create_git_switch_branch`, `buildmaster_git_post_install_marker_for_srcdir` |
| Paths / options | `library_import_hint`, `library_import_static_hint`, `buildmaster_parse_subcomponent`, `buildmaster_parse_component_options`, `ensure_build_dir`, `sanitize_for_filename` |
| Toolchain | `buildmaster_load_toolchain_profile`, `buildmaster_validate_toolchain` |

Stage generators (`create_*_stages`) are **internal**. They are not part of
the supported public surface.

---

## Self-tests

Synthetic harness under `.github/tests/` (not part of the installed DSL
surface). Edit expectations under `.github/tests/expected/`; fixtures live
under `.github/tests/harness/fixtures/`.

```bash
cmake -S .github/tests/harness -B build/harness -G Ninja
cmake --build build/harness --target run_buildmaster_checks
cmake --build build/harness --target run_buildmaster_smoke
```

Coverage includes flat graphs, order-independent declaration, prerequisites,
file decompress and checksums, file-to-component wiring, a non-destructive
git sandbox (local clone), component-to-component link, recursive CMake and
Meson nests, install rename normalization, and **WHOLE** (positive
whole-archive link + negative control without WHOLE, with a second library
kept outside the whole region).

---

## License

MIT. See [`LICENSE`](LICENSE).
