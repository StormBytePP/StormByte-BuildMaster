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
whole-archive static linking, **meta collections**, and failure behaviour
that does not leave the parent compiling against a half-empty prefix.

## Table of contents

- [What it is](#what-it-is)
- [Why it exists](#why-it-exists)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [Declarative model](#declarative-model)
- [How a component works](#how-a-component-works)
- [Dependencies and links](#dependencies-and-links)
- [Meta components](#meta-components)
- [Orphan warnings](#orphan-warnings)
- [Prerequisites](#prerequisites)
- [Component options string](#component-options-string)
- [Whole-archive linking (WHOLE)](#whole-archive-linking-whole)
- [Subcomponent specs and library paths](#subcomponent-specs-and-library-paths)
- [Header-only components](#header-only-components)
- [Per-component toolchains](#per-component-toolchains)
- [Recursive usage](#recursive-usage)
- [Logging](#logging)
- [Verbosity of tool output](#verbosity-of-tool-output)
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
- group components into **meta** collections (`create_meta_component` +
  `meta_component_add`) with optional `WHOLE` on the collection
- create deterministic **IMPORTED** (or **INTERFACE`) targets
- share one install prefix and environment across a dependency tree
- fail the parent when a required external stage fails
- optionally build **one** component with a different toolchain than the job
- attach downloads, unpack steps, or custom work via **prerequisite** targets
- mark static components so consumers pull **entire** archives (`WHOLE`)

Sources can come from the Git helpers, file helpers, a submodule, or anything
else that produces a source tree.

Typical uses: bundled third-party libraries, multi-variant builds of the same
tree, header-only SDK graphs, mixed CMake + Meson graphs on Linux, Windows,
and macOS (including Apple Silicon), plugin packs that FFmpeg (or similar)
links as one node.

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
linker. BuildMaster can attach that policy to a component’s INTERFACE, or to
a **meta** that collects many plugins.

Generated stages look like this:

```text
<component>_configure
<component>_build
<component>_install
```

A meta has the same names as anchors (`<meta>_install` waits on members) but
does not compile or install artifacts of its own.

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
| Meta collections (no sources) | No | Manual INTERFACE | **Yes** |
| Path-qualified subcomponents (`subdir/name`) | No | Manual | **Yes** |
| Whole-archive static link on INTERFACE | Manual | Manual | **Optional (`WHOLE`)** |
| Unified log API (`buildmaster_message`) | No | No | **Yes** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |
| Fail-fast after a stage failure | No | Manual | **Optional** |
| INTERFACE depends on `_install` | No | Manual | **Yes** |
| Orphan component / meta warning | No | No | **Yes** |
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
- Meta collections that only group graph + INTERFACE (optional `WHOLE`)
- Optional per-component toolchains that never rewrite the parent toolchain
- One initialization, one install root, even in nested trees
- Quiet logs by default; one log API for BuildMaster and parent projects
- Predictable failure: a broken required component fails the parent graph
- Configure **WARNING** listing unused (orphan) components and metas
- Git ops bound to a component id (configure-time, then optional reset)
- File helpers as build targets wired through the same dependency graph
- Extensible options via one trailing `KEY=value;…` string
- Library artifacts that can live in a **subdir** of the shared libdir
- Optional whole-archive policy per static component or meta (`WHOLE`)

---

## Quick start

```cmake
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")  # optional

add_subdirectory(path/to/buildmaster)
include(path/to/buildmaster/helpers.cmake)

buildmaster_message(USER STATUS "Setting up My Library" 1)

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
2. **Optional collections:** `create_meta_component` + `meta_component_add`
   (`add` may happen before `create_meta_component`).
3. **Connect** them with `component_dependency` and/or `component_link`
   (declaration order does not matter).
4. **Optional** work before a component: `component_prerequisite`,
   `file_download` / `file_download_cached` / `file_decompress`, or
   configure-time `create_git_*`.
5. At the end of `CMAKE_SOURCE_DIR`, BuildMaster **materializes** stages and
   applies links. Consumers never call finalize (it is internal).
   Unused ids get a single **WARNING**.

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
Ninja) can depend on real files.

Component **ids** should be filesystem-friendly (they become target and
script names). Display **titles** may contain spaces; they only appear in
status lines.

---

## Dependencies and links

### `component_dependency(source, dest)`

Order-only edge. At materialize time, `dest` resolves as (first match):

1. Registered component id → `<id>_install`
2. Registered **meta** id → `<id>_install`
3. Name matching `*_install` / `*_configure` / `*_build`
4. Existing CMake target (e.g. `component_prerequisite`, `file_*` target)

Otherwise materialization fails with **FATAL_ERROR**.

### `component_link(source, dest)`

Records a link from the component `INTERFACE`. When `dest` is a **graph
node** (registered component, **meta**, stage name, or existing target), it
also records `component_dependency`. Pure library specs do **not** get an
automatic dependency edge.

Host application targets are **not** BuildMaster graph nodes: link them with
ordinary `target_link_libraries(MyApp PRIVATE <component_id>)`.

---

## Meta components

A **meta** is an `INTERFACE` + graph anchor. It has **no sources**, does not
compile, and does not install its own artifacts. It collects members
(components, other metas, static or shared) and forwards wait + link.

### Membership vs consumption

| Call | Meaning |
|------|---------|
| `meta_component_add(meta, member…)` | **Membership.** `member` belongs to `meta`. |
| `component_link` / `component_dependency` / host `target_link_libraries` **to the meta** | **Consumption.** The collection is actually pulled into the build. |

The container does **not** replace linking. If nothing consumes the meta, its
members are not built just because they were added.

`meta_component_add` may run **before** `create_meta_component`. Cycles
(`plugins → codecs → plugins`) are **FATAL**.

```cmake
meta_component_add(ffmpeg-plugins zlib)
meta_component_add(ffmpeg-plugins png)
create_meta_component(ffmpeg-plugins "FFmpeg plugins" "INDENT=1;WHOLE")
component_link(ffmpeg ffmpeg-plugins)
```

---

## Orphan warnings

At finalize, components and metas that were never consumed (link, dependency,
host link, or a **used** repack) are listed in one **WARNING**. Membership in
an unused meta does not count as consumption.

---

## Prerequisites

`component_prerequisite(<id> <existing_target>)` orders `<id>_configure`
after a host or helper target (download, unpack, custom work).

---

## Component options string

Every `create_*_component` accepts **at most one** optional trailing
argument:

```text
KEY=value;KEY2=value with spaces
```

| Rule | Detail |
|------|--------|
| Pair separator | `;` |
| Key / value | Only the **first** `=` in a pair |
| Keys | Case-insensitive, stored **UPPERCASE** |
| Values | May contain spaces and extra `=` |
| `;` in a value | Not allowed |
| Bare flag | `RENAME` / `WHOLE` / `BUILDONLY` ≡ `KEY=ON` |
| Unknown key | **WARNING**, ignored |
| Extra positional args | **FATAL_ERROR** |

| Key | Meaning |
|-----|---------|
| `INDENT` / `INDENT_LEVEL` | Tabs after the log header (non-negative integer) |
| `TOOLCHAIN` | Profile (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `RENAME` | Normalize installed (or BUILDONLY build-dir) archives to the declared name |
| `WHOLE` | Whole-archive link of produced static archives (ignored with warning on shared/headers) |
| `BUILDONLY` | No install into the shared prefix; artifacts stay in the component build dir |

---

## Whole-archive linking (WHOLE)

On **static** components (and metas that opt in), produced archives are
linked as one linear whole-archive group:

```text
--whole-archive  A  B  --no-whole-archive     # ELF
-force_load A  -force_load B                  # Mach-O
/WHOLEARCHIVE:A.lib  /WHOLEARCHIVE:B.lib      # MSVC
```

Shared / headers / BUILDONLY: `WHOLE` is ignored with a warning. Several
WHOLE components on one consumer stay **linear**, not nested.

---

## Subcomponent specs and library paths

| Spec | File | IMPORTED target |
|------|------|-----------------|
| `mylib` | `${BUILDMASTER_INSTALL_LIBDIR}/libmylib.a` | `mylib` |
| `vendor/foo/foolib` | `${BUILDMASTER_INSTALL_LIBDIR}/vendor/foo/libfoolib.a` | `vendor_foo_foolib` |

```cmake
library_import_static_hint(out name prefix [subdir])
library_import_hint(out name prefix [subdir])
```

A static `.a` does not pull other static archives. List every required spec
on the outermost component (or `component_link` them).

---

## Header-only components

`create_cmake_headers_component` / `create_meson_headers_component`: no
IMPORTED archive; install stamp under the include tree; `INTERFACE` +
`SYSTEM` include of `BUILDMASTER_INSTALL_INCLUDEDIR`.

---

## Per-component toolchains

`TOOLCHAIN=` selects a profile for **that component only**.

| Name | Drivers | Linker |
|------|---------|--------|
| `gcc` | `gcc` / `g++` | System default |
| `clang` | `clang` / `clang++` | LLD required on **Linux**; not forced on **macOS** |
| `clang-cl` | `clang-cl` | `lld-link` + `llvm-lib` (Windows) |
| `msvc` | `cl` | `link.exe` + `lib.exe` (Windows) |

Unknown names fail at configure and list known profiles. Nested Meson uses
the matching native file (`BUILDMASTER_MESON_NATIVE_FILE`), including when
the toolchain is inherited.

---

## Recursive usage

An external CMake project may `add_subdirectory(buildmaster)` again.
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses
`BUILDMASTER_INSTALL_DIR`, markers, scripts, and the log level.

Pass the repo root if nested projects need to find BuildMaster:

```cmake
create_cmake_component(
	nest
	"Nested"
	${NEST_SRC} ${NEST_BUILD}
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"vendor/nest/nestlib;vendor/nest/midlib"
)
```

---

## Logging

All BuildMaster diagnostics go through one API. **Do not use CMake
`message()`** in a project that uses BuildMaster (or in BuildMaster itself,
except `log.cmake`). Raw `message()` bypasses the level filter, breaks the
aligned headers, and cannot follow `BUILDMASTER_LOGLEVEL`.

### `buildmaster_message`

```cmake
buildmaster_message(<module> <level> "<text>" [<indent>])
```

| Argument | Meaning |
|----------|---------|
| `module` | Who is speaking. Internal keys below, or **`USER`** from a parent project. |
| `level` | `LOWLEVEL`, `DEBUG`, `INFO`, `WARNING`, `STATUS`, `FATAL` (always uppercase). |
| `text` | Body. The header is never indented. |
| `indent` | Optional tab count **after** the header (default `0`). |

`USER` is the reserved module for **consumer** projects (header label
`User`). Use it for lines such as “Setting up Opus”, not an internal name
like `CMake` or `Opus`.

```cmake
buildmaster_message(USER STATUS "Setting up Opus codec" 1)
buildmaster_message(USER INFO  "DNN model already cached" 2)
buildmaster_message(USER FATAL "opus_data hash missing")
```

```text
-- [BuildMaster/User     ]: 	Setting up Opus codec
-- [INFO    ][BuildMaster/User     ]: 		DNN model already cached
```

### Levels

Numeric order is ascending (higher = quieter filter threshold):

| Level | Role |
|-------|------|
| `LOWLEVEL` | Function enter/exit and path plumbing. |
| `DEBUG` | Useful when debugging BuildMaster or a consumer graph. |
| `INFO` | Optional progress (rename skip, unpack OK, harness checks). |
| `WARNING` | Shown when the current level is `INFO` or more verbose. Hidden at `STATUS` and `FATAL`. |
| `STATUS` | Default. Stage lines (`Configuring` / `Compiling` / `Installing`) and consumer titles. |
| `FATAL` | Always printed. Stops configure/script. Never filtered. |

`FATAL` as **`BUILDMASTER_LOGLEVEL`** is the quietest user setting: only
`FATAL` lines remain. It is allowed and discouraged.

An unknown level (typo `DEHBUG`, invented `MYDEBUG`) is **FATAL** and lists
the accepted names.

### Filter

A line is printed when its level number is **≥** the current
`BUILDMASTER_LOGLEVEL`, except:

- `FATAL` is never dropped.
- `WARNING` is dropped when the current level is stricter than `INFO`.

### Format

- Header is never indented. Optional tabs apply only to the body.
- `STATUS`: `[BuildMaster/<Module>]: <tabs><text>`
- Any other level: `[<LEVEL>][BuildMaster/<Module>]: <tabs><text>` (no space
  between the two brackets).
- `<LEVEL>` is uppercase and padded to the longest level name (`LOWLEVEL`).
- `<Module>` is CamelCase and padded to the longest module label
  (`Toolchain`).

Ninja `COMMENT` strings use the same `STATUS` header via
`buildmaster_log_comment()` so stage lines align with configure output.

### Selecting the level

```bash
export BUILDMASTER_LOGLEVEL=DEBUG
# or
cmake -DBUILDMASTER_LOGLEVEL=INFO …
```

Default is `STATUS`. `BUILDMASTER_DEBUG` is **ignored** (removed).

Change the level and **re-run CMake** so generated `-P` scripts see it.

### Built-in modules

| Key | Header label | Typical owner |
|-----|--------------|---------------|
| `ARCHIVE` | Archive | Static merge / archiver |
| `CMAKE` | CMake | CMake stages |
| `COMPONENT` | Component | Component factory / graph |
| `CORE` | Core | Bootstrap, harness, helpers |
| `ENV` | Env | Environment runners |
| `EXTRA` | Extra | Extra tools (pkgconf, …) |
| `FILE` | File | Download / decompress |
| `GIT` | Git | Reset / patch / fetch |
| `MESON` | Meson | Meson stages |
| `NINJA` | Ninja | Ninja helpers |
| `RENAME` | Rename | Archive name normalization |
| `TOOLCHAIN` | Toolchain | Profiles / native files |
| `TOOLS` | Tools | Tool bootstrap |
| `USER` | User | **Parent project only** |

Unknown module keys are **FATAL** and list the accepted set.

---

## Verbosity of tool output

`BUILDMASTER_LOGLEVEL` only filters **BuildMaster lines**. Live compiler /
linker stdout is a separate switch:

```bash
export BUILDMASTER_VERBOSE=1
```

| Stage | Effect |
|-------|--------|
| `cmake --build` | Live compile runner + `--verbose` |
| `meson compile` | Live compile runner + `-v` |
| Configure / setup / install / git | Unchanged unless you raise `LOGLEVEL` |

`LOGLEVEL` does **not** imply `VERBOSE`. Silent runners still hide tool
stdout on success and dump it on failure.

| LOGLEVEL (typical) | VERBOSE | BuildMaster lines | Compile lines |
|--------------------|---------|-------------------|---------------|
| `STATUS` | off | Stage titles | Quiet |
| `DEBUG` | off | Graph + git + paths | Quiet |
| `STATUS` | on | Stage titles | Live + `--verbose` / `-v` |
| `LOWLEVEL` | on | Everything | Live + `--verbose` / `-v` |

---

## Fail-fast

A non-zero nested build/install fails that stage. The INTERFACE target
depends on `<component>_install`.

Optional markers:

```bash
export BUILDMASTER_FAIL_FAST=1
```

| Value | Behaviour |
|-------|-----------|
| **ON** | First failure writes markers; later stages skip and fail. |
| **OFF** (default) | Independent components can continue (cache warm). |

---

## Compiler cache

If the parent sets `CMAKE_C_COMPILER_LAUNCHER` /
`CMAKE_CXX_COMPILER_LAUNCHER` and/or `CCACHE_DIR` / `SCCACHE_DIR`,
BuildMaster forwards them to env runners, child CMake, and Meson setup.

On Windows, launchers are **not** folded into `CC`/`CXX`.

---

## Platform notes

| Topic | Linux | Windows | macOS |
|-------|-------|---------|-------|
| Env runner | `runner.sh` | PowerShell `runner_silent.ps1` | same as Linux |
| Static merge | GNU `ar` / `llvm-ar` | `lib /OUT:` | `libtool -static` |
| Meson PDB | — | `/Z7` | — |
| `TOOLCHAIN=clang` | LLD required | use `clang-cl` | LLD not forced |
| `TOOLCHAIN=msvc` / `clang-cl` | invalid | supported | invalid |

---

## Git helpers

```cmake
create_git_reset_file(mylib "MyLib reset" ${MYLIB_SRC_DIR})
create_git_patch_file(mylib "MyLib patch" ${MYLIB_SRC_DIR} "${MYLIB_PATCH}")
create_meson_component(mylib "My Library"
	${MYLIB_SRC_DIR} ${MYLIB_BUILD_DIR} "${MYLIB_OPTIONS}"
	shared "mylib")
```

| Function | Action |
|----------|--------|
| `create_git_reset_file` | `reset --hard` + `clean -fdx` |
| `create_git_patch_file` | `git apply` |
| `create_git_fetch` | `git fetch` |
| `create_git_switch_branch` | switch / track branch |

Git stdout (including `HEAD is now at …`) is captured and logged with
`buildmaster_message(GIT …)`, not printed raw.

---

## File download and decompress

Destination is always `${BUILDMASTER_DOWNLOADSDIR}/<url-basename>`.

| Function | Role |
|----------|------|
| `file_download_cached` | Reuse file when hash matches |
| `file_download` | Always download, retry, verify hash |
| `file_decompress` | `file(ARCHIVE_EXTRACT)` |

Wire them with `component_prerequisite` when a component must wait.

---

## API map

| Area | Where |
|------|--------|
| Logging | `log.cmake` → `buildmaster_message`, `buildmaster_log_comment` |
| Component factory | `component/helpers.cmake` |
| Meta | `component/meta.cmake` |
| Options parser | `buildmaster_parse_component_options` |
| Subcomponent parse | `buildmaster_parse_subcomponent` |
| Path hints | `helpers.cmake` |
| CMake stages | `tools/cmake/helpers.cmake` |
| Meson stages | `tools/meson/helpers.cmake` |
| Toolchain profiles | `toolchain/helpers.cmake`, `toolchain/profiles/` |
| Git | `tools/git/helpers.cmake` |
| File helpers | `tools/file/helpers.cmake` |
| Env runners | `env/helpers.cmake` |

---

## Self-tests

```bash
cmake -S .github/tests/harness -B build/harness -G Ninja
cmake --build build/harness --target run_buildmaster_checks
cmake --build build/harness --target run_buildmaster_smoke
```

Contract lists live under `.github/tests/expected/`. Details:
`.github/tests/README.md`.

---

## License

MIT. See [`LICENSE`](LICENSE).
