# StormByte BuildMaster

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Meson](https://img.shields.io/badge/Meson-supported-orange)
![Ninja](https://img.shields.io/badge/Ninja-supported-0f4c81)
![Status](https://img.shields.io/badge/status-active-success)

A **fully declarative** CMake DSL that turns external **CMake** and **Meson**
projects into first-class pieces of a parent tree: order-independent
registration, deferred materialization, explicit stage targets, one shared
install prefix, portable static bundling, header-only components, optional
per-component toolchains, and failure behaviour that does not leave the parent
compiling against a half-empty prefix.

## Table of contents

- [What it is](#what-it-is)
- [Why it exists](#why-it-exists)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [Declarative model](#declarative-model)
- [How a component works](#how-a-component-works)
- [component_dependency and component_link](#component_dependency-and-component_link)
- [Component options string](#component-options-string)
- [Produced libraries](#produced-libraries)
- [Install archive normalize (RENAME)](#install-archive-normalize-rename)
- [Subcomponent specs and library paths](#subcomponent-specs-and-library-paths)
- [Header-only components](#header-only-components)
- [Per-component toolchains](#per-component-toolchains)
- [Recursive usage](#recursive-usage)
- [Verbosity and diagnostics](#verbosity-and-diagnostics)
- [Fail-fast](#fail-fast)
- [Compiler cache](#compiler-cache)
- [Platform notes](#platform-notes)
- [Static library bundling](#static-library-bundling)
- [Git helpers](#git-helpers)
- [File download and decompress](#file-download-and-decompress)
- [API map](#api-map)
- [Self-tests](#self-tests)
- [Examples](#examples)
- [License](#license)

---

## What it is

You **declare** components and edges. BuildMaster **materializes** them at the
end of configure (automatic deferred finalize): stage scripts, `INTERFACE` /
`IMPORTED` targets, and the install contract.

The parent can then:

- link against deterministic targets without managing fragment paths
- inspect installed headers and libraries before the main build
- attach `POST_BUILD` / install hooks to real stage targets
- share one install prefix and environment across a dependency tree
- fail the parent when a required external stage fails
- optionally build **one** component with a different toolchain than the job

It is not only a source fetcher. Sources can come from the Git helpers, the
file download helpers, a submodule, or anything else.

Typical uses: bundled third-party libraries, multi-variant builds of the same
tree, header-only SDK graphs, mixed CMake + Meson graphs on Linux, Windows,
and macOS (including Apple Silicon).

---

## Why it exists

`ExternalProject_Add` configures and builds **at build time**. Too late to
branch on results, generate import targets from real paths, or enforce one
install layout.

`FetchContent` brings sources in but does not orchestrate CMake **and** Meson
with the same model.

Meson does not inherit `PKG_CONFIG_PATH`, prefix, compilers, flags, or cache
launchers the way nested CMake does. Without a control layer, nested Meson
often misses previous `.pc` files or uses the wrong toolchain.

A failed compile can still leave other components installing while the parent
compiles against missing headers.

Some upstreams misbehave under one compiler. BuildMaster can pin **only that
component** to another toolchain.

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
| Configure external project | N/A | Build time | **Configure or build stage** |
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
| Declarative dependency / link graph | No | Manual | **Yes** |
| Order-independent declaration | No | Manual | **Yes** |
| Post-install archive name normalize (`RENAME`) | No | Manual | **Yes** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |
| Fail-fast after a stage failure | No | Manual | **Optional** |
| INTERFACE depends on `_install` | No | Manual | **Yes** |
| Git reset + reconfigure (`buildmaster_clean`) | No | Manual | **Optional** |
| Per-repo post-install git reset | No | Manual | **Yes** |

---

## Design goals

- **Declarative** registration: declare components and edges in any order
- Automatic materialization at the end of the parent configure
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
- Git ops bound to a component id
- Extensible options via one trailing `KEY=value;…` string
- Library artifacts that can live in a **subdir** of the shared libdir
- Canonical produced names even when upstream installs variant basenames

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

# Optional: order edges and extra link archives (any order relative to create_*)
# component_dependency(mylib otherlib)
# component_link(mylib "vendor/extra")

target_link_libraries(MyApp PRIVATE mylib)
```

No out-variable and no `include()` of a generated fragment. Targets appear
after deferred finalize (end of `CMAKE_SOURCE_DIR` processing).

Optional trailing options string:

```cmake
create_cmake_component(
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

## Declarative model

| Phase | What happens |
|-------|----------------|
| **Declare** | `create_*`, `component_dependency`, `component_link` only register metadata and edges. Order does not matter. |
| **Finalize** | At the end of configure of `CMAKE_SOURCE_DIR`, BuildMaster materializes every component (stage scripts + fragment `include`) and applies links. |

- Components **without** a dependency on another install/target configure during
  parent **configure** (eager).
- Components **with** such a dependency configure at **build** time under
  `<id>_configure` (deferred), after prerequisites.

Custom user targets (download, unpack, codegen) can be prerequisites via
`component_dependency(mycomp my_custom_target)`.

---

## How a component works

`create_cmake_component` / `create_meson_component` register a component.
After finalize, the graph contains:

| Target | Role |
|--------|------|
| `<component>` | `INTERFACE`. Depends on `<component>_install`. This is what you link. |
| `<component>_configure` | Nested CMake/Meson configure (and registered git ops) |
| `<component>_build` | Compile |
| `<component>_install` | Install into `BUILDMASTER_INSTALL_DIR` |
| `<libspec>` | `STATIC`/`SHARED` **IMPORTED** archive(s) for each produced entry and library-spec `component_link` dest |

Library-mode install lists archive paths as `OUTPUT` so Ninja tracks real
files. Paths come from **produced** plus library specs from
`component_link`. By default, missing produced names may be filled by
**renaming** upstream variant archives (`RENAME`). The stage then requires
every listed path to exist; it does not write empty placeholder `.a` / `.lib`
files.

Component **ids** should be filesystem-friendly (they become target and script
names). Display **titles** may contain spaces; they only appear in status lines.

Stage generators (`create_*_stages`) are **internal**. Prefer the component API.

---

## component_dependency and component_link

### `component_dependency(source, dest)`

Order only (no link line).

| Argument | Typical values |
|----------|----------------|
| `source` | Component id (edge attaches to deferred configure when applicable) |
| `dest` | Component id → `<dest>_install`; existing CMake target; or `<id>_install` / `_configure` / `_build` |

```cmake
component_dependency(harfbuzz freetype)
component_dependency(opus opus_dnn_data)   # user custom target
```

### `component_link(source, dest)`

Link **and** order (records a dependency as well).

| `dest` form | Effect |
|-------------|--------|
| Registered component | Link all of dest’s produced IMPORTED libs (+ INTERFACE) |
| Library spec `name` or `subdir/name` | IMPORTED under install libdir; listed on source install `OUTPUT` when needed |
| Existing CMake target | `target_link_libraries(… INTERFACE …)` |
| Filesystem path to an archive | Linked as a file |

```cmake
create_cmake_component(nest … static "recursive/cmake/nestlib")
component_link(nest "recursive/cmake/midlib")
component_link(nest "recursive/cmake/leaflib")
target_link_libraries(MyApp PRIVATE nest)
```

A static `.a` does not pull other static archives by itself; declare them with
`component_link` (or list them in produced if this component installs them).

---

## Component options string

Every `create_*` accepts **at most one** optional trailing argument:

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
| Empty value | Legal (`TOOLCHAIN=` means inherit) |
| Flag without `=` | Only for declared flag keys (today: `RENAME`). `RENAME` ≡ `RENAME=ON` |
| Unknown key | **WARNING**, ignored |
| Extra positional args | **FATAL_ERROR** |

| Key | Meaning |
|-----|---------|
| `INDENT` / `INDENT_LEVEL` | Tabs in hierarchical `STATUS` lines (non-negative integer) |
| `TOOLCHAIN` | Profile name (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `RENAME` | **Flag** (default **ON**). Normalize variant install names to produced paths |

`LINK_EXTRA` is **removed**; use `component_link`.

```cmake
create_cmake_component(... "mylib")
create_cmake_component(... "mylib" "INDENT=2")
create_cmake_component(... "mylib" "TOOLCHAIN=msvc")
create_cmake_component(... "mylib" "INDENT=1;TOOLCHAIN=msvc")
create_meson_component(... "z" "RENAME")
create_meson_component(... "z" "RENAME=OFF")
```

---

## Produced libraries

The positional argument after `static` / `shared` is the **produced** list:
archives this component installs as its primary contract. At least one entry is
required (library modes).

Specs from `component_link` that resolve to install-prefix library paths are
also added to the install `OUTPUT` list so Ninja has a production rule.

MSVC DLLs still live under `BUILDMASTER_INSTALL_BINDIR` using the **basename
only**.

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
ignores `RENAME`. Variant tokens live in `tools/rename/variants.cmake`.

Declare produced as the **real** contract name (`z` on MSVC, not `libz`).

```cmake
create_meson_component(
	zlib
	"zlib"
	${ZLIB_SRC}
	${ZLIB_BUILD}
	"${ZLIB_OPTS}"
	static
	"z"
	"RENAME"
)
```

---

## Subcomponent specs and library paths

Each entry in produced (or a library-spec `component_link` dest) is a library
**spec**:

| Spec | File | IMPORTED target |
|------|------|-----------------|
| `mylib` | `${BUILDMASTER_INSTALL_LIBDIR}/libmylib.a` | `mylib` |
| `vendor/foo/foolib` | `${BUILDMASTER_INSTALL_LIBDIR}/vendor/foo/libfoolib.a` | `vendor_foo_foolib` |

- Last path component = library basename (`foolib`).
- Everything before it = subdir under `BUILDMASTER_INSTALL_LIBDIR`.
- `/` in the spec becomes `_` in the CMake target name.
- Windows uses `.lib` / import-library suffixes via the same helpers.

```cmake
library_import_static_hint(out name prefix [subdir])
library_import_hint(out name prefix [subdir])
```

`subdir` is optional and relative to `prefix` (usually
`BUILDMASTER_INSTALL_LIBDIR`).

---

## Header-only components

Projects that install only headers use headers mode (no IMPORTED archive, no
empty archive `OUTPUT` list).

| Stage | Behaviour |
|-------|-----------|
| configure | Nested CMake or Meson setup |
| build | Still runs (often a no-op) so the graph stays uniform |
| install | Into `BUILDMASTER_INSTALL_DIR` |
| OUTPUT | Stamp under the install include tree |
| Target | `INTERFACE` + `SYSTEM` include of `BUILDMASTER_INSTALL_INCLUDEDIR` + depend on `_install` |

```cmake
create_cmake_headers_component(
	sdk-headers
	"SDK Headers"
	${HEADERS_SRC}
	${HEADERS_BUILD}
	"-DENABLE_TESTS=OFF"
	"INDENT=1"
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

Meson twin: `create_meson_headers_component`.

---

## Per-component toolchains

By default every component inherits the **job** compilers, linker and archiver.
`TOOLCHAIN=` in the options string selects a profile for **that component
only**.

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

Profiles: `toolchain/profiles/`.

```cmake
create_cmake_component(
	speciallib
	"Special Library"
	${SPECIAL_SRC}
	${SPECIAL_BUILD}
	"${SPECIAL_OPTIONS}"
	static
	"speciallib"
	"TOOLCHAIN=msvc"
)
```

---

## Recursive usage

An external CMake project may `add_subdirectory(buildmaster)` again.
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses
`BUILDMASTER_INSTALL_DIR`, markers, and generated scripts.

Pass the repo root into nested projects if they need to find BuildMaster.
Install nested archives under a **subdir** of the shared libdir. Use
**produced** for the outer archive and `component_link` for transitive static
archives installed in the same nested graph:

```cmake
create_cmake_component(
	nest
	"Nested"
	${NEST_SRC}
	${NEST_BUILD}
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"vendor/nest/nestlib"
)
component_link(nest "vendor/nest/midlib")
component_link(nest "vendor/nest/leaflib")
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
include(${LIB_RESET})
include(${LIB_PATCH})

create_cmake_component(
	mylib
	"My Library"
	${MYLIB_SRC_DIR}
	${MYLIB_BUILD}
	"${MYLIB_OPTS}"
	static
	"mylib"
)
```

Git steps run as part of that component’s configure path.

---

## File download and decompress

```cmake
file_download_cached(DL_SCRIPT
	"https://example.com/data.tar.gz"
	TITLE "Example data"
	EXPECTED_HASH "SHA256=…"
)
include(${DL_SCRIPT})

file_decompress(UNPACK_SCRIPT
	"${BUILDMASTER_DOWNLOADSDIR}/data.tar.gz"
	${UNPACK_DIR}
	TITLE "Example data"
)
include(${UNPACK_SCRIPT})
```

Downloads are cache-aware under `BUILDMASTER_DOWNLOADSDIR`. For build-time
ordering relative to a component, wrap the work in a custom target and
`component_dependency(mycomp that_target)`.

---

## API map

| Area | Public entry points |
|------|---------------------|
| Components | `create_component`, `create_cmake_component`, `create_meson_component`, `create_cmake_headers_component`, `create_meson_headers_component` |
| Graph | `component_dependency`, `component_link` |
| Options / specs | `buildmaster_parse_component_options`, `buildmaster_parse_subcomponent` |
| Paths | `ensure_build_dir`, `library_import_hint`, `library_import_static_hint`, `sanitize_for_filename` |
| Git | `create_git_fetch`, `create_git_patch_file`, `create_git_reset_file`, `create_git_switch_branch` |
| Files | `file_download`, `file_download_cached`, `file_decompress` |
| Toolchain | `buildmaster_load_toolchain_profile`, `buildmaster_validate_toolchain` |

Stage generators and finalize helpers are **internal**.

---

## Self-tests

Synthetic harness under `.github/tests/` (no real third-party projects).

```bash
cmake -S .github/tests/harness -B build/harness -G Ninja
cmake --build build/harness --target run_buildmaster_checks
cmake --build build/harness --target run_buildmaster_smoke
```

| Path | Role |
|------|------|
| `.github/tests/expected/` | Expected public functions, vars, edges, smoke targets/artifacts |
| `.github/tests/harness/fixtures/` | Tiny projects (including order-independent and recursive chains) |

See `.github/tests/README.md` for how to extend expectations when adding API.

---

## Examples

### Order does not matter

```cmake
component_dependency(second first)
component_link(second first)

create_cmake_component(second "Second" ${SECOND_SRC} ${SECOND_BUILD} "" static "secondlib")
create_cmake_component(first  "First"  ${FIRST_SRC}  ${FIRST_BUILD}  "" static "firstlib")

target_link_libraries(app PRIVATE second)
```

### Eager vs deferred configure

```cmake
create_cmake_component(ogg … static "ogg")           # configures at configure-time
create_cmake_component(vorbis … static "vorbis")
component_dependency(vorbis ogg)                     # vorbis configures at build-time
```

### Nested static chain

```cmake
create_cmake_component(
	nest "Nested" ${NEST_SRC} ${NEST_BUILD}
	"-DBUILDMASTER_ROOT=${ROOT}"
	static
	"recursive/cmake/nestlib"
)
component_link(nest "recursive/cmake/midlib")
component_link(nest "recursive/cmake/leaflib")
target_link_libraries(app PRIVATE nest)
```

---

## License

MIT. See [`LICENSE`](LICENSE).
