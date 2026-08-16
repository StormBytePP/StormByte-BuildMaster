# StormByte BuildMaster

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Meson](https://img.shields.io/badge/Meson-supported-orange)
![Ninja](https://img.shields.io/badge/Ninja-supported-0f4c81)
![Status](https://img.shields.io/badge/status-active-success)

A small **CMake DSL** to configure, build, install and consume external
**CMake** and **Meson** projects as first-class parts of a parent tree —
with **configure-time** stages, explicit targets, and coherent environment
propagation.

## Table of contents

- [Overview](#overview)
- [Motivation](#motivation)
- [Comparison](#comparison)
- [Design goals](#design-goals)
- [Quick start](#quick-start)
- [Output verbosity](#output-verbosity)
- [Recursive usage](#recursive-usage)
- [Usage modes](#usage-modes)
- [Targets and naming](#targets-and-naming)
- [API reference (where to look)](#api-reference-where-to-look)
- [Git helpers](#git-helpers)
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

It is **not** a source fetcher only (unlike a pure `FetchContent` workflow):
it orchestrates full external builds. Sources may still be managed with the
included Git helpers or any other means.

---

## Motivation

`ExternalProject_Add` configures and builds dependencies **at build time**.
By then it is too late for the parent to:

- branch on configure results
- generate import targets from real artifact paths
- enforce a single, shared install layout

`FetchContent` brings sources into the tree but does not, by itself, provide
a uniform model for multi-system (CMake + Meson) build/install orchestration.

BuildMaster fills that gap with **configure-time** generated scripts and
explicit targets:

```text
<component>_build
<component>_install
```

---

## Comparison

| Capability | FetchContent | ExternalProject_Add | BuildMaster |
|------------|:------------:|:-------------------:|:-----------:|
| Fetch / manage sources | Yes | Yes | Yes (Git helpers optional) |
| Configure external project | N/A | Build time | **Configure time** |
| Inspect artifacts before main build | No | No | **Yes** |
| Explicit `_build` / `_install` targets | No | No | **Yes** |
| Attach post-steps to those targets | No | Limited | **Yes** |
| Native Meson stages | No | Manual | **Yes** |
| Shared install + env propagation | No | Manual | **Yes** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |

---

## Design goals

- Deterministic **configure-time** orchestration
- Coherent environment (`PATH`, `PKG_CONFIG_PATH`, `LIB`, `INCLUDE`, compilers, flags)
- **Linux / Windows / macOS**
- CMake and Meson behind the same component API
- Generated scripts that are inspectable and CI-friendly
- One initialization, one install root, even in deep dependency trees

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

## Output verbosity

By default each stage prints a short status line (for example
`Compiling …` / `Installing …`) so large dependency graphs stay readable.

Set:

```bash
export BUILDMASTER_VERBOSE=1
```

to surface underlying configure/build tool stdout and stderr (and to stop
suppressing “silent” runners). Useful in CI when a third-party configure fails.

---

## Recursive usage

An external CMake project may itself `add_subdirectory(buildmaster)`.  
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses the
same `BUILDMASTER_INSTALL_DIR` and generated script tree, so nested projects
do not fight over prefixes or double-bootstrap tools.

---

## Usage modes

### Simple (recommended)

Use `create_cmake_component()`, `create_meson_component()`, or the dependant
variants. One generated fragment declares imports and wires stages.

### Advanced

Call `create_cmake_stages()` / `create_meson_stages()` yourself, then
`include()` the three scripts (configure, build, install) in the order you
need—e.g. to insert custom commands between stages.

---

## Targets and naming

| Target | Role |
|--------|------|
| `<component>_build` | Compile the external project |
| `<component>_install` | Install into `BUILDMASTER_INSTALL_DIR` |

Install rules list produced libraries as `OUTPUT`, so other targets can
`DEPENDS` on real files, not only on phony names.

Component ids used in target names should stay filesystem-friendly; display
titles (e.g. `VVenc (H266) codec`) may contain spaces or punctuation and are
only used in status messages.

---

## API reference (where to look)

| Area | File |
|------|------|
| Component factory (simple API) | `component/helpers.cmake` |
| CMake stages | `tools/cmake/helpers.cmake` |
| Meson stages | `tools/meson/helpers.cmake` |
| Git fragments | `tools/git/helpers.cmake` |
| Env runners / `prepare_command` | `env/helpers.cmake` |
| Path / list / sanitize utils | `helpers.cmake` |
| Tool registration | `tools/helpers.cmake` |

Templates (generated into the build tree):

- `tools/cmake/{configure,build,install}.cmake.in`
- `tools/meson/{setup,compile,install}.cmake.in`

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

---

## License

MIT. See [`LICENSE`](LICENSE) for the full text.
