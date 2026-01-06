# StormByte BuildMaster

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)(LICENSE)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![CMake DSL](https://img.shields.io/badge/CMake-DSL-blueviolet)
![Meson](https://img.shields.io/badge/build-meson%20supported-orange)
![Ninja](https://img.shields.io/badge/build-ninja%20supported-0f4c81)
![Status](https://img.shields.io/badge/status-active-success)
![Type](https://img.shields.io/badge/type-build%20engine-lightgrey)

## Table of Contents

- [Overview](#overview)
- [Why Build Master exists](#why-build-master-exists)
- [Design goals (brief)](#design-goals-brief)
- [How to use (quick start)](#how-to-use-quick-start)
 - [Output verbosity](#output-verbosity)
 - [Recursive configurations](#recursive-configurations)
- [Two usage modes](#two-usage-modes)
  - [Simple mode — high level](#simple-mode---high-level)
  - [Advanced mode — explicit stages](#advanced-mode---explicit-stages)
- [Targets and naming](#targets-and-naming)
- [Important functions (where to look)](#important-functions-where-to-look)
- [Helpers and utilities](#helpers-and-utilities)
- [Templates and implementation notes](#templates-and-implementation-notes)
- [Git handling](#git-handling)
- [Examples](#examples)
  - [Dependent components](#dependent-components)
- [Why this matters](#why-this-matters)
- [Next steps / where to inspect](#next-steps--where-to-inspect)
- [License](#license)

---

## Overview

Build Master is a small DSL extension for CMake that makes it simple and reliable to build, install and consume external CMake and Meson projects from a parent CMake tree. It was created to work around a common limitation of `ExternalProject_Add`: external projects are typically configured at build time, which prevents the parent CMake from observing and reacting to configure-time results.

Build Master generates configure / compile / install stages **during CMake configure time**, allowing the parent project to inspect artifacts, create import targets, and adjust environment variables deterministically.

---

## Why Build Master exists

When a CMake project needs to build external dependencies as part of its own build, the usual tool — `ExternalProject_Add` — has several structural limitations:

- External projects are configured **at build time**, not at configure time.  
  This prevents the parent CMake project from inspecting results, generating import targets, or adjusting logic based on the external project's configuration.

- It does not provide **full, explicit targets** for each stage.  
  You cannot attach `POST_BUILD` commands to a clean `<component>_build` or `<component>_install` target because those targets simply do not exist.

- Environment propagation is inconsistent and must be manually handled.

- Integration with Meson projects requires custom glue and is not deterministic.

Additionally, unlike `FetchContent`, Build Master does not merely download sources — it orchestrates **full configure/build/install stages** with environment propagation and explicit targets.

Build Master solves these issues by generating deterministic stages during configure time, exposing targets such as:

```
<component>_build
<component>_install
```

This makes it trivial to attach post-build actions, inspect installed artifacts, and integrate external projects as if they were native parts of the parent build.

---

## Design goals (brief)

- Deterministic configure-time behavior.
- Coherent environment propagation (`PKG_CONFIG_PATH`, `PATH`, `LIB`, `INCLUDE`, etc.).
- Cross-platform support (Windows, Linux, macOS).
- Modular helpers and templates for CMake and Meson.
- Reproducible builds: all external steps are scripted and version-controlled.

---

## How to use (quick start)

Using Build Master in a project is intentionally simple — three steps:

```cmake
# optional: enable extra tools (e.g. pkgconf)
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")

# add the Build Master tree to your project
add_subdirectory(buildmaster)

# import the helper DSL
include(buildmaster/helpers.cmake)
```

What these lines do:

- `BUILDMASTER_INITIALIZE_EXTRA_TOOLS`: optional list of extra tools that are not initialized by default.
- `add_subdirectory(buildmaster)`: configures and initializes Build Master.
- `include(buildmaster/helpers.cmake)`: imports helper functions such as `create_component()`, `create_cmake_component()`, `create_meson_component()` and other utilities.

After this you can declare components:

```cmake
set(options "-DENABLE_FOO=ON")
create_cmake_component(OUT_FILE
                       opus
                       "Opus Audio Codec"
                       ${CMAKE_SOURCE_DIR}/thirdparty/opus
                       ${CMAKE_BINARY_DIR}/thirdparty/opus_build
                       "${options}"
                       shared
                       "")
include(${OUT_FILE})
```

Notes:

- The first argument (`OUT_FILE`) receives the generated fragment path.
- After `include(${OUT_FILE})`, the imported targets and stage targets (`<component>_build`, `<component>_install`) become available.

---

## Output verbosity

By default Build Master produces minimal, concise output: a single brief line for each stage — configure, build and install — so that CMake output remains compact when managing many components. To enable full, verbose output for the configure and build stages set the environment variable `BUILDMASTER_DEBUG` to `1`. When `BUILDMASTER_DEBUG` is `1` Build Master will show the underlying configure and build tool output (stdout/stderr) to help diagnose configure-time or build-time problems.

## Recursive configurations

Build Master is designed to support recursive usage: an external CMake project may itself use Build Master to orchestrate its dependencies, and those dependencies may also use Build Master, recursively. This is possible because Build Master is initialized only once (for example by `add_subdirectory(buildmaster)`) and all recursive instances share the same installation location (the unified `BUILDMASTER_INSTALL_DIR`). Nested projects therefore reuse the same initialization state and installation layout, avoiding duplicate initializations and conflicting install paths while ensuring deterministic behavior across parent and subproject boundaries.

## Two usage modes

### Simple mode — high level

- Call `create_component()` or the wrappers `create_cmake_component()` / `create_meson_component()`.
- A per-component CMake fragment is generated and returned.
- The fragment declares imported targets and wires build/install stages.

### Advanced mode — explicit stages

- Call `create_cmake_stages()` or `create_meson_stages()` directly.
- Three scripts are generated: configure, build, install.
- Include them manually to customize ordering or attach `POST_BUILD` steps.

---

## Targets and naming

- All components define stage targets:

```
<component>_build
<component>_install
```

- Install commands declare their produced files as `OUTPUT`, so other targets can depend on them.

---

## Important functions (where to look)

- `create_component(_out_var _component _component_title _srcdir _builddir _options _library_mode _build_system _subcomponents _dependency)`
- `create_cmake_stages(_file_configure _file_compile _file_install _component _component_title _srcdir _builddir _options _library_mode _output_libraries)`
- `create_meson_stages(...)`

---

## Helpers and utilities

- `library_import_hint()`
- `library_import_static_hint()`
- `library_dll_hint()`
- `sanitize_for_filename()`
- `list_join()`
- `prepare_command()`

These helpers are used internally by templates but can also be used by the user.

---

## Templates and implementation notes

CMake templates:

- `tools/cmake/configure.cmake.in`
- `tools/cmake/build.cmake.in`
- `tools/cmake/install.cmake.in`

Meson templates:

- `tools/meson/setup.cmake.in`
- `tools/meson/compile.cmake.in`
- `tools/meson/install.cmake.in`

Templates are versioned and can be customized if needed.

---

## Git handling

Build Master includes helpers that generate Git-related scripts under the generated scripts tree.

Examples:

```cmake
create_git_fetch(GIT_FETCH_FILE
                 myrepo
                 ${CMAKE_SOURCE_DIR}/thirdparty/myrepo)
include(${GIT_FETCH_FILE})
```

```cmake
create_git_patch_file(GIT_PATCH_FILE
                      myrepo
                      ${CMAKE_SOURCE_DIR}/thirdparty/myrepo
                      "${CMAKE_SOURCE_DIR}/patches/patch1.diff;${CMAKE_SOURCE_DIR}/patches/patch2.diff}")
include(${GIT_PATCH_FILE})
```

Scripts are generated under `BUILDMASTER_SCRIPTS_GIT_DIR`.

---

## Examples

### Simple mode

```cmake
add_subdirectory(path/to/buildmaster)
include(buildmaster/helpers.cmake)

set(options "-DENABLE_FEATURE=ON")
create_cmake_component(LIB_CREATE_FILE
                       mylib
                       "My Library"
                       ${CMAKE_SOURCE_DIR}/third_party/mylib
                       ${CMAKE_BINARY_DIR}/third_party/mylib_build
                       "${options}"
                       shared
                       "")
include(${LIB_CREATE_FILE})
```

### Advanced mode

```cmake
create_cmake_stages(cfg_script build_script install_script
                    mylib "My Library"
                    ${CMAKE_SOURCE_DIR}/third_party/mylib
                    ${CMAKE_BINARY_DIR}/third_party/mylib_build
                    "-DENABLE_FEATURE=ON"
                    shared "/path/to/output/libmylib.so")

include(${cfg_script})
include(${build_script})
include(${install_script})
```

---

## Dependent components

```cmake
create_cmake_component(B_FILE
                       libb
                       "LibB"
                       ${CMAKE_SOURCE_DIR}/thirdparty/libb
                       ${CMAKE_BINARY_DIR}/thirdparty/libb_build
                       "${options}"
                       shared
                       "")
include(${B_FILE})

create_cmake_dependant_component(A_FILE
                                 liba
                                 "LibA"
                                 ${CMAKE_SOURCE_DIR}/thirdparty/liba
                                 ${CMAKE_BINARY_DIR}/thirdparty/liba_build
                                 "${options}"
                                 shared
                                 ""
                                 "libb_install")
include(${A_FILE})
```

---

## Why this matters

Handling external dependencies in CMake has traditionally required a mix of build‑time orchestration, custom scripts, and tool‑specific glue. `ExternalProject_Add` postpones all meaningful work until build-time, while `FetchContent` focuses only on retrieving sources. This leaves a gap: the parent project cannot reliably inspect configuration results, adjust logic, or propagate environments during the phase where these decisions actually matter.

Build Master closes that gap by introducing a configure‑time orchestration model. Each external component becomes a small declarative unit with explicit, versioned stages—configure, build, install—generated during CMake’s configure phase. This gives the parent project immediate visibility into artifacts, options, and environment changes, making integration more predictable and reducing the need for ad‑hoc workarounds.

A key aspect of this model is that **all rules are defined during the initial configure step**, even when a component depends on another that has not yet been built. The DSL generates the full set of scripts and configuration fragments up front, including “late‑configure” rules that will only execute once their prerequisites exist. This ensures that the entire dependency graph is known and fixed from the start. As a result, build-time behavior becomes straightforward: the only issues that may appear are genuine compilation or configuration errors originating from the external projects themselves, not from missing or dynamically generated build logic.

The DSL also provides a unified way to orchestrate CMake projects, Meson projects, and Git-based sources under the same rules and installation layout. This consistency is especially helpful in larger codebases where different components rely on different build systems or tooling.

Reproducibility is a core principle. All stages are scripted, version-controlled, and executed with a fully propagated environment, ensuring that local builds, CI pipelines, and recursive subprojects behave the same way. Nested projects share a unified installation directory and initialization state, avoiding duplication and preventing conflicts across dependency trees.

In practice, Build Master turns external dependency handling into a clear, deterministic, and inspectable part of the build system. It reduces friction, improves maintainability, and provides a solid foundation for modular architectures, SDKs, multimedia engines, and any project that relies on external components.

---

## Next steps / where to inspect

- High-level helpers: `component/helpers.cmake`
- CMake stage generator: `tools/cmake/helpers.cmake`
- Meson stage generator: `tools/meson/helpers.cmake`
- Git helpers: `tools/git`

---

## License

Build Master is distributed under the MIT License.  
See the `LICENSE` file for full details.
