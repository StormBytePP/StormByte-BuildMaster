# StormByte BuildMaster

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Meson](https://img.shields.io/badge/Meson-supported-orange)
![Ninja](https://img.shields.io/badge/Ninja-supported-0f4c81)
![Status](https://img.shields.io/badge/status-active-success)

A small **CMake DSL** that turns external **CMake** and **Meson** projects
into first-class pieces of a parent tree: configure-time stages, explicit
targets, one shared install prefix, portable static bundling, header-only
components, optional per-component toolchains, and failure behaviour that
does not leave the parent compiling against a half-empty prefix.

## Table of contents

- [What it is](#what-it-is)
- [Why it exists](#why-it-exists)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [How a component works](#how-a-component-works)
- [Component options string](#component-options-string)
- [Produced libraries and LINK_EXTRA](#produced-libraries-and-link_extra)
- [Install archive normalize (RENAME)](#install-archive-normalize-rename)
- [Subcomponent specs and library paths](#subcomponent-specs-and-library-paths)
- [Header-only components](#header-only-components)
- [Dependant components](#dependant-components)
- [Per-component toolchains](#per-component-toolchains)
- [Recursive usage](#recursive-usage)
- [Verbosity and diagnostics](#verbosity-and-diagnostics)
- [Fail-fast](#fail-fast)
- [Compiler cache](#compiler-cache)
- [Platform notes](#platform-notes)
- [Static library bundling](#static-library-bundling)
- [Git helpers](#git-helpers)
- [File download and decompress](#file-download-and-decompress)
- [Advanced: raw stages](#advanced-raw-stages)
- [API map](#api-map)
- [Self-tests](#self-tests)
- [Examples](#examples)
- [License](#license)

---

## What it is

BuildMaster generates **configure / build / install** stages while the
parent project is still in the **CMake configure phase**. The parent can
then:

- inspect installed headers and libraries before the main build
- create deterministic **IMPORTED** (or **INTERFACE**) targets
- attach `POST_BUILD` / install hooks to real stage targets
- share one install prefix and environment across a dependency tree
- fail the parent when a required external stage fails
- optionally build **one** component with a different toolchain than the job

It is not only a source fetcher. Sources can come from the Git helpers, the
file download helpers, a submodule, or anything else.

Typical uses: bundled third-party libraries, multi-variant builds of the
same tree, header-only SDK graphs, mixed CMake + Meson graphs on Linux,
Windows, and macOS (including Apple Silicon).

---

## Why it exists

`ExternalProject_Add` configures and builds **at build time**. Too late to
branch on results, generate import targets from real paths, or enforce one
install layout.

`FetchContent` brings sources in but does not orchestrate CMake **and**
Meson with the same model.

Meson does not inherit `PKG_CONFIG_PATH`, prefix, compilers, flags, or
cache launchers the way nested CMake does. Without a control layer, nested
Meson often misses previous `.pc` files or uses the wrong toolchain.

A failed compile can still leave other components installing while the
parent compiles against missing headers.

Some upstreams misbehave under one compiler. BuildMaster can pin **only
that component** to another toolchain.

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
| Configure external project | N/A | Build time | **Configure stage** |
| Inspect artifacts before main build | No | No | **Yes** |
| Explicit `_configure` / `_build` / `_install` | No | No | **Yes** |
| Attach post-steps to those targets | No | Limited | **Yes** |
| Native Meson stages | No | Manual | **Yes** |
| Shared install + env propagation | No | Manual | **Yes** |
| Compiler cache into child builds | Manual | Manual | **Yes** |
| Per-component toolchain | No | Manual | **Optional** |
| Portable static archive merge | No | Manual | **Yes** |
| Header-only INTERFACE components | Manual | Manual | **Yes** |
| Path-qualified library specs (`subdir/name`) | No | Manual | **Yes** |
| Produced vs extra link archives (`LINK_EXTRA`) | No | Manual | **Yes** |
| Post-install archive name normalize (`RENAME`) | No | Manual | **Yes** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |
| Fail-fast after a stage failure | No | Manual | **Optional** |
| INTERFACE depends on `_install` | No | Manual | **Yes** |
| Git reset + reconfigure (`buildmaster_clean`) | No | Manual | **Optional** |
| Per-repo post-install git reset | No | Manual | **Yes** |

---

## Design goals

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
- Extensible options via one trailing `KEY=value;…` string
- Library artifacts that can live in a **subdir** of the shared libdir
- Clear split between **produced** archives and **extra** link archives
- Canonical produced names even when upstream installs variant basenames

---

## Quick start

```cmake
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")  # optional

add_subdirectory(path/to/buildmaster)
include(path/to/buildmaster/helpers.cmake)

set(_opts "-DENABLE_FOO=ON")
create_cmake_component(
	OUT_FILE
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"${_opts}"
	shared
	"mylib"
)
include(${OUT_FILE})

target_link_libraries(MyApp PRIVATE mylib)
```

After `include(${OUT_FILE})` the stage targets and IMPORTED libraries exist
in the parent.

The positional library list is **produced** (what this component installs).
Optional behaviour goes in a **single** trailing options string:

```cmake
create_cmake_component(
	OUT_FILE
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"${_opts}"
	shared
	"mylib"
	"INDENT=2;TOOLCHAIN=clang-cl"
)
```

---

## How a component works

`create_cmake_component` / `create_meson_component` generate three stage
scripts and a fragment that declares:

| Target | Role |
|--------|------|
| `<component>` | `INTERFACE`. Depends on `<component>_install`. This is what you link. |
| `<component>_configure` | Nested CMake/Meson configure (and registered git ops) |
| `<component>_build` | Compile |
| `<component>_install` | Install into `BUILDMASTER_INSTALL_DIR` |
| `<libspec>` | `STATIC`/`SHARED` **IMPORTED** archive(s) for each produced and `LINK_EXTRA` entry |

Library-mode install lists archive paths as `OUTPUT` so Ninja tracks real
files. Paths come from the **produced** list plus optional `LINK_EXTRA`
(when those archives are materialised by the same install graph). By
default, missing produced names may be filled by **renaming** upstream
variant archives (`RENAME`). The stage then requires every listed path to
exist; it does not write empty placeholder `.a` / `.lib` files.

Component **ids** should be filesystem-friendly (they become target and
script names). Display **titles** may contain spaces; they only appear in
status lines.

---

## Component options string

Every `create_*_component` / `create_*_dependant_component` /
`create_*_headers_*` function accepts **at most one** optional trailing
argument:

```text
"KEY=value;KEY2=value with spaces"
```

| Rule | Detail |
|------|--------|
| Pair separator | `;` |
| Key / value | Only the **first** `=` in a pair |
| Keys | Case-insensitive, stored **UPPERCASE** |
| Values | May contain spaces and extra `=` |
| `;` in a value | Not allowed (it would start another pair) |
| Empty value | Legal (`TOOLCHAIN=` means inherit) |
| Flag without `=` | Only for declared flag keys (today: `RENAME`). `RENAME` ≡ `RENAME=ON` |
| Unknown key | **WARNING**, ignored |
| Extra positional args | **FATAL_ERROR** |

| Key | Meaning |
|-----|---------|
| `INDENT` / `INDENT_LEVEL` | Tabs in hierarchical `STATUS` lines (non-negative integer) |
| `TOOLCHAIN` | Profile name (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `LINK_EXTRA` | Comma-separated library specs also wired as IMPORTED on the INTERFACE |
| `RENAME` | **Flag** (default **ON**). Normalize variant install names to produced paths |

```cmake
create_cmake_component(... "mylib")
create_cmake_component(... "mylib" "INDENT=2")
create_cmake_component(... "mylib" "TOOLCHAIN=msvc")
create_cmake_component(... "mylib" "INDENT=1;TOOLCHAIN=msvc")
create_cmake_component(... "nestlib"
	"LINK_EXTRA=midlib,leaflib")
create_meson_component(... "z" "RENAME")
create_meson_component(... "z" "RENAME=OFF")
```

---

## Produced libraries and LINK_EXTRA

The positional argument after `static` / `shared` is the **produced** list:
archives this component is responsible for as its primary install artefacts.
At least one entry is required (library modes).

| List | Role |
|------|------|
| **Produced** (positional) | Primary archives. Always IMPORTED and on the install `OUTPUT` list. |
| **`LINK_EXTRA=`** (options) | Additional specs for the INTERFACE link line (and IMPORTED targets). Also listed on install `OUTPUT` when the same install stage materialises them (typical for nested BuildMaster). |

Omit `LINK_EXTRA` when consumers only need what this component installs.

A static `.a` does not pull other static archives by itself. For a nested
chain (`nest` → `mid` → `leaf`), put the outer archive in **produced** and
the transitive ones in `LINK_EXTRA`:

```cmake
create_cmake_component(
	OUT nest "Nested stack"
	${NEST_SRC} ${NEST_BUILD} "${OPTS}"
	static
	"recursive/cmake/nestlib"
	"LINK_EXTRA=recursive/cmake/midlib,recursive/cmake/leaflib"
)
include(${OUT})
target_link_libraries(MyApp PRIVATE nest)
```

If `LINK_EXTRA` points at archives installed only by a **sibling**
component, also ensure the graph waits on that component’s `_install`.

MSVC DLLs still live under `BUILDMASTER_INSTALL_BINDIR` using the
**basename only**.

---

## Install archive normalize (`RENAME`)

Upstream (especially **Meson** or MSVC) often installs variant basenames
(`zs.lib`, `zd.lib`, `libzs.a`, …) while **produced** expects the canonical
name (`z.lib` / `libz.a`).

When `RENAME` is enabled (default for library modes):

1. Nested install runs as usual.
2. For each produced archive path that is still missing, BuildMaster searches
   the same directory for the same stem plus known variants and **renames**
   the first match to the canonical path.
3. Shared libraries on Windows also try to pair the matching `.dll`.
4. The install stage then requires every produced path to exist.

If the canonical file is already present, rename is skipped. Headers mode
ignores `RENAME`. Variant tokens live in one internal list
(`tools/rename/variants.cmake`); `install_exec` only decides whether to run
the normalizer.

Declare produced as the **real** contract name (`z` on MSVC, not `libz`).

```cmake
create_meson_component(
	OUT zlib "zlib"
	${ZLIB_SRC} ${ZLIB_BUILD} "${ZLIB_OPTS}"
	static
	"z"
	# default; omit or use RENAME=OFF to disable
	"RENAME"
)
```

---

## Subcomponent specs and library paths

Each entry in produced or `LINK_EXTRA` is a library **spec**:

| Spec | File | IMPORTED target |
|------|------|-----------------|
| `mylib` | `${BUILDMASTER_INSTALL_LIBDIR}/libmylib.a` | `mylib` |
| `vendor/foo/foolib` | `${BUILDMASTER_INSTALL_LIBDIR}/vendor/foo/libfoolib.a` | `vendor_foo_foolib` |

- Last path component = library basename (`foolib`).
- Everything before it = subdir under `BUILDMASTER_INSTALL_LIBDIR`.
- `/` in the spec becomes `_` in the CMake target name.
- Windows uses `.lib` / import-library suffixes via the same helpers.

Implemented by `buildmaster_parse_subcomponent()`. Paths are built with:

```cmake
library_import_static_hint(out name prefix [subdir])
library_import_hint(out name prefix [subdir])
```

`subdir` is optional and relative to `prefix` (usually
`BUILDMASTER_INSTALL_LIBDIR`).

---

## Header-only components

Projects that install only headers (no `.a` / `.lib` / `.so`) use
`headers` mode. There is no IMPORTED archive and no empty archive `OUTPUT`
list (which breaks under CMP0175).

| Stage | Behaviour |
|-------|-----------|
| configure | Nested CMake or Meson setup |
| build | Still runs (often a no-op) so the graph stays uniform |
| install | Into `BUILDMASTER_INSTALL_DIR` |
| OUTPUT | Stamp under the install include tree |
| Target | `INTERFACE` + `SYSTEM` include of `BUILDMASTER_INSTALL_INCLUDEDIR` + depend on `_install` |

```cmake
create_cmake_headers_component(
	HEADERS_FILE
	sdk-headers
	"SDK Headers"
	${HEADERS_SRC}
	${HEADERS_BUILD}
	"-DENABLE_TESTS=OFF"
	"INDENT=1"
)
include(${HEADERS_FILE})

create_cmake_dependant_component(
	LOADER_FILE
	sdk-loader
	"SDK Loader"
	${LOADER_SRC}
	${LOADER_BUILD}
	""
	static
	"sdkloader"
	"sdk-headers_install"
)
include(${LOADER_FILE})
```

Meson twins: `create_meson_headers_component`,
`create_meson_headers_dependant_component`.

Signatures omit `_library_mode` and the produced list (always `headers`).

---

## Dependant components

Use `create_*_dependant_component` when configure of A must wait for B’s
**install**:

```cmake
create_cmake_component(B_FILE libb "LibB" ${B_SRC} ${B_BUILD} "" shared "libb")
include(${B_FILE})

create_cmake_dependant_component(
	A_FILE
	liba
	"LibA"
	${A_SRC}
	${A_BUILD}
	"${options}"
	shared
	"liba"
	"libb_install"
)
include(${A_FILE})
```

The dependant configure runs under a custom target so hierarchical
`STATUS` lines stay quiet (the target `COMMENT` is enough).

---

## Per-component toolchains

By default every component inherits the **job** compilers, linker and
archiver. `TOOLCHAIN=` in the options string selects a profile for **that
component only**.

| Name | Drivers | Linker |
|------|---------|--------|
| `gcc` | `gcc` / `g++` | System default |
| `clang` | `clang` / `clang++` | LLD required on **Linux**; not forced on **macOS** |
| `clang-cl` | `clang-cl` | `lld-link` + `llvm-lib` (Windows) |
| `msvc` | `cl` | `link.exe` + `lib.exe` (Windows) |

- Omit the key (or leave it empty) to inherit the parent.
- Override covers configure, build and install of that component.
- Isolated: no rewrite of the parent toolchain file or global env runner.
- Unknown names fail at configure and list known profiles.
- `msvc` / `clang-cl` only on Windows; `gcc` / `clang` are not accepted as
  component toolchains on Windows.

Profiles: `toolchain/profiles/`. Validation: `toolchain/helpers.cmake`.

```cmake
create_cmake_component(
	SPECIAL_FILE speciallib "Special Library"
	${SPECIAL_SRC} ${SPECIAL_BUILD} "${SPECIAL_OPTIONS}"
	static "speciallib"
	"TOOLCHAIN=msvc"
)
include(${SPECIAL_FILE})
```

---

## Recursive usage

An external CMake project may `add_subdirectory(buildmaster)` again.
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses
`BUILDMASTER_INSTALL_DIR`, markers, and generated scripts.

Pass the repo root into nested projects if they need to find BuildMaster.
Install nested archives under a **subdir** of the shared libdir. Use
**produced** for the outer archive and `LINK_EXTRA` for transitive static
archives installed in the same nested graph:

```cmake
create_cmake_component(
	NEST_FILE nest "Nested"
	${NEST_SRC} ${NEST_BUILD}
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"vendor/nest/nestlib"
	"LINK_EXTRA=vendor/nest/midlib,vendor/nest/leaflib"
)
```

Per-component `TOOLCHAIN` stays local to the component that requested it.

---

## Verbosity and diagnostics

Default: a short line per stage. Silent runners hide tool stdout/stderr
**on success**. On failure they dump the captured log to stderr.

### DEBUG (everything live)

```bash
export BUILDMASTER_DEBUG=1
# or cmake -DBUILDMASTER_DEBUG=ON
```

### VERBOSE (compiles only)

```bash
export BUILDMASTER_VERBOSE=1
```

| Stage | Effect |
|-------|--------|
| `cmake --build` | Live compile runner + `--verbose` |
| `meson compile` | Live compile runner + `-v` |
| Configure / setup / install / git | Unchanged unless `DEBUG` |

`DEBUG` does **not** imply `VERBOSE`. Re-run CMake after changing these flags.

---

## Fail-fast

### Always

A non-zero build/install fails that stage. The INTERFACE target depends on
`<component>_install`, so linking waits for a successful install.

### Optional markers (`BUILDMASTER_FAIL_FAST`)

```bash
export BUILDMASTER_FAIL_FAST=1   # 1, ON, TRUE, YES
```

| Value | Behaviour |
|-------|-----------|
| **ON** | First failed build/install writes markers. Later stages skip and fail. |
| **OFF** (default) | No markers. Better for warming caches. |

```text
${BUILDMASTER_BINDIR}/markers/buildmaster.failed
${BUILDMASTER_BINDIR}/markers/<component_id>.failed
```

`buildmaster_build_init` clears `markers/` at the start of every parent build.

---

## Compiler cache

If the parent sets `CMAKE_C_COMPILER_LAUNCHER` /
`CMAKE_CXX_COMPILER_LAUNCHER` and/or `CCACHE_DIR` / `SCCACHE_DIR`,
BuildMaster forwards them to env runners, child CMake, and Meson setup.

On Windows, launchers are **not** folded into `CC`/`CXX`. Leave
`BUILDMASTER_FAIL_FAST` unset when warming caches.

---

## Platform notes

| Topic | Linux | Windows | macOS |
|-------|-------|---------|-------|
| Env runner | `runner.sh` | `runner.bat` | same as Linux |
| Static merge | GNU `ar -M` | `lib /OUT:` | `libtool -static` |
| Meson PDB | — | `/Z7` | — |
| Generated CMake paths | `/` | `TO_CMAKE_PATH` | `/` |
| `TOOLCHAIN=clang` | LLD required | use `clang-cl` | LLD not forced |
| `TOOLCHAIN=msvc` / `clang-cl` | invalid | supported | invalid |
| `subdir/name` archives | `lib` or `lib64` | `lib` + `.lib` | `lib` |
| Variant install names | often `libzs.a` | often `zs.lib` | same idea |

`RENAME` is especially useful when Meson or MSVC emit non-canonical basenames
while produced expects the platform hint from `library_import_static_hint`.

---

## Static library bundling

```cmake
library_import_static_hint(MERGED_LIBRARY "mylib" "${BUILDMASTER_INSTALL_LIBDIR}")

create_bundle_static_libraries(
	BUNDLE_SCRIPT
	"mylib"
	"${LIB_A};${LIB_B};${LIB_C}"
)

add_custom_command(TARGET mylib_install POST_BUILD
	COMMAND ${ENV_CMAKE_SILENT_COMMAND} -E remove "${MERGED_LIBRARY}"
	COMMAND ${BUNDLE_SCRIPT}
	COMMENT "Repacking static libraries"
)
```

| Platform | Tool |
|----------|------|
| Linux | GNU `ar -M` |
| macOS | `libtool -static` |
| Windows | `lib /OUT:` |

---

## Git helpers

Git ops are bound to the same **component id** used in `create_*`.

```cmake
create_git_reset_file(LIB_RESET mylib "MyLib reset" ${MYLIB_SRC_DIR})
create_git_patch_file(LIB_PATCH mylib "MyLib patch" ${MYLIB_SRC_DIR} "${MYLIB_PATCH}")
create_meson_component(OUT mylib "My Library"
	${MYLIB_SRC_DIR} ${MYLIB_BUILD_DIR} "${MYLIB_OPTIONS}"
	shared "mylib")
include(${OUT})
```

| Function | Action |
|----------|--------|
| `create_git_reset_file` | `reset --hard` + `clean -fd` |
| `create_git_patch_file` | `git apply` |
| `create_git_fetch` | `git fetch` |
| `create_git_switch_branch` | switch / track branch |

Call `create_git_*` **before** `create_*_component` so registration is
visible when stages are generated. Scripts run at the start of
`<component>_configure`. After a successful install, that repo is reset
again (toplevel of that tree only).

### `buildmaster_clean`

Default `BUILDMASTER_CLEAN_RESET_REPOS=ON`:

```bash
cmake --build build --target buildmaster_clean
```

Not wired to the generator’s `clean` (unreliable with Ninja).

---

## File download and decompress

| Function | Role |
|----------|------|
| `file_download_cached` | Reuse file when hash matches |
| `file_download` | Always download, retry, verify hash |
| `file_decompress` | `file(ARCHIVE_EXTRACT)` |

Destination is always `${BUILDMASTER_DOWNLOADSDIR}/<url-basename>`. Hash form:
`ALGO=hex` (e.g. `SHA256=…`).

---

## Advanced: raw stages

`create_cmake_stages` / `create_meson_stages` if you need to insert commands
between stages. Pass **full** artifact paths in `_output_libraries`. Optional
args (`indent`, `toolchain`, `configure_via_target`) remain on the stage API.
`_BM_RENAME_ENABLED` defaults to ON when unset.

---

## API map

| Area | Where |
|------|--------|
| Component factory | `component/helpers.cmake` (`create_component`, options parser) |
| CMake component wrappers | `component/cmake/helpers.cmake` (`create_cmake_*`) |
| Meson component wrappers | `component/meson/helpers.cmake` (`create_meson_*`) |
| Subcomponent parse | `buildmaster_parse_subcomponent` |
| Header wrappers | `create_*_headers_*` (same backend helper files) |
| Static bundler | `create_bundle_static_libraries` |
| Path hints | `helpers.cmake` → `library_import_hint`, `library_import_static_hint` |
| CMake stages | `tools/cmake/helpers.cmake` |
| Meson stages | `tools/meson/helpers.cmake` |
| Toolchain profiles | `toolchain/helpers.cmake`, `toolchain/profiles/` |
| Git | `tools/git/helpers.cmake` |
| File helpers | `tools/file/helpers.cmake` |
| Env runners | `env/helpers.cmake` |
| Sanitize / paths / lists | `helpers.cmake` |
| Fail-fast / init | `init_vars.cmake` |

Component module paths (exported / toolchain):

| Variable | Points to |
|----------|-----------|
| `BUILDMASTER_COMPONENT_SRCDIR` | `component/` (module root) |
| `BUILDMASTER_COMPONENT_TEMPLATEDIR` | `component/templates/` (`.in` fragments and bundler templates) |
| `BUILDMASTER_SCRIPTS_COMPONENTDIR` | Generated per-component fragments under the scripts tree |

Templates for stage wiring live under `component/templates/`
(`component_{static,shared,headers}{,_dependant}.cmake.in`, `bundler*.in`).
Other modules keep their `*.cmake.in` / `runner_*.in` next to themselves.

---

## Self-tests

```bash
cmake -S tests/harness -B build/harness -G Ninja
cmake --build build/harness --target run_buildmaster_checks
cmake --build build/harness --target run_buildmaster_smoke
```

Edit lists under `tests/expected/` when extending coverage. The harness
includes a Meson **rename** fixture (`zs.*` → produced `z.*`). Details:
`tests/README.md`.

---

## Examples

### CMake library

```cmake
create_cmake_component(
	LIB_CREATE_FILE
	mylib "My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"-DENABLE_FEATURE=ON"
	shared
	"mylib"
)
include(${LIB_CREATE_FILE})
```

### Nested static chain

```cmake
create_cmake_component(
	NEST_FILE nest "Nested stack"
	${NEST_SRC} ${NEST_BUILD}
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"recursive/cmake/nestlib"
	"LINK_EXTRA=recursive/cmake/midlib,recursive/cmake/leaflib"
)
include(${NEST_FILE})
target_link_libraries(MyApp PRIVATE nest)
```

### Meson with variant install name

```cmake
create_meson_component(
	OUT zlib "zlib"
	${ZLIB_SRC} ${ZLIB_BUILD} "${ZLIB_OPTS}"
	static
	"z"
	"RENAME"
)
include(${OUT})
```

### Header-only

```cmake
create_cmake_headers_component(
	HEADERS_FILE sdk-headers "SDK Headers"
	${CMAKE_SOURCE_DIR}/thirdparty/sdk-headers
	${CMAKE_BINARY_DIR}/thirdparty/sdk-headers_build
	"-DENABLE_TESTS=OFF"
)
include(${HEADERS_FILE})
```

### Indent + toolchain

```cmake
create_cmake_component(
	OUT mylib "My Library"
	${SRC} ${BUILD} "${OPTS}"
	static "mylib"
	"INDENT=2;TOOLCHAIN=clang-cl"
)
include(${OUT})
```

---

## License

MIT. See [`LICENSE`](LICENSE).
