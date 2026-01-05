# StormByte BuildMaster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Status](https://img.shields.io/badge/status-active-success)
![Type](https://img.shields.io/badge/type-build%20engine-lightgrey)

## Table of Contents

- [Overview](#overview)
- [Design goals (brief)](#design-goals-brief)
- [How to use (quick start)](#how-to-use-quick-start)
- [Two usage modes](#two-usage-modes)
  - [Simple mode — high level](#simple-mode---high-level)
  - [Advanced mode — explicit stages](#advanced-mode---explicit-stages)
- [Targets and naming](#targets-and-naming)
- [Important functions (where to look)](#important-functions-where-to-look)
- [Helpers and utilities](#helpers-and-utilities)
- [Templates and implementation notes](#templates-and-implementation-notes)
- [Examples](#examples)
  - [Dependent components](#dependent-components)
- [Why this matters](#why-this-matters)
- [Next steps / where to inspect](#next-steps--where-to-inspect)
- [License](#license)

## Overview

Build Master is a small DSL extension for CMake that makes it simple and reliable to build, install and consume external CMake and Meson projects from a parent CMake tree. It was created to work around a common limitation of `ExternalProject_Add`: external projects are typically configured at build time, which prevents the parent CMake from observing and reacting to configure-time results. Build Master generates configure / compile / install stages at CMake configure time so the parent project can inspect artifacts, create import targets, and adjust environment variables deterministically.

### Why Build Master exists

When a CMake project needs to build external dependencies as part of its own build, the usual tool — `ExternalProject_Add` — has several structural limitations:

- External projects are configured at build time, not at configure time.  
  This prevents the parent CMake project from inspecting results, generating import targets, or adjusting logic based on the external project's configuration.
- It does not provide full, explicit targets for each stage.  
  You cannot attach POST_BUILD commands to a clean `<component>_build` or `<component>_install` target because those targets simply do not exist.
- Environment propagation is inconsistent and must be manually handled.
- Integration with Meson projects requires custom glue and is not deterministic.

Build Master solves these issues by generating configure/build/install stages during CMake configure time, exposing deterministic targets such as:

`<component>_build`  
`<component>_install`

This makes it trivial to attach post-build actions, inspect installed artifacts, and integrate external projects as if they were native parts of the parent build.

## Design goals (brief)

- Deterministic configure-time behavior: run external config steps during the configure phase so results can be used immediately.
- Coherent environment propagation: ensure PKG_CONFIG_PATH, PATH, platform LIB/INCLUDE, and other environment variables are consistently set for every tool.
- Cross-platform: handle Windows vs Unix differences, MSVC import-naming, and runner scripts.
- Modular: small, testable helpers and templates for CMake and Meson components.

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

- `BUILDMASTER_INITIALIZE_EXTRA_TOOLS`: optional list of extra tools that are not initialized by default (for example `pkgconf`).
- `add_subdirectory(buildmaster)`: configures and initializes Build Master.
- `include(buildmaster/helpers.cmake)`: imports helper functions such as `create_component()`, `create_cmake_component()`, `create_meson_component()` and other utilities.

After this you can declare components. Example (simple):

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

- The first argument to `create_cmake_component` is the name of the variable that will receive the generated fragment path (here `OUT_FILE`).
- After `include(${OUT_FILE})` the generated imported targets and the stage targets (`<component>_build`, `<component>_install`) are available to the parent project.

That’s all — Build Master will generate configure/build/install stages, wire targets, and expose import targets for immediate consumption.

## Two usage modes

### Simple mode — high level

- Call `create_component()` or the convenience wrappers `create_cmake_component()` / `create_meson_component()`.
- This generates a per-component CMake fragment (configured from templates) that declares imported targets and wires the build/install stages into the parent project.
- The generated fragment path is returned in the caller's variable (the first argument you pass).

### Advanced mode — explicit stages

- Call `create_cmake_stages()` or `create_meson_stages()` directly to produce three scripts: `configure`, `build/compile`, `install`.
- Include those generated scripts in your tree to define explicit targets and customize ordering or add POST_BUILD steps.

## Targets and naming

- All created components define stage targets named `<component>_build` and `<component>_install` (for example `opus_build` / `opus_install`). This makes it trivial to attach post-build or install-time actions to component stages.
- Install commands declare their produced files as OUTPUT, so other targets can DEPENDS on installed artifacts.

## Important functions (where to look)

- `create_component(_out_var _component _component_title _srcdir _builddir _options _library_mode _build_system _subcomponents _dependency)` — high-level generator that emits a per-component fragment, sets up library filenames and stage names, and writes the fragment path into the parent scope variable named by `_out_var`.

- `create_cmake_stages(_file_configure _file_compile _file_install _component _component_title _srcdir _builddir _options _library_mode _output_libraries)` — creates three configured scripts under the generated scripts directory and returns their paths. The scripts are produced from `tools/cmake/*.in` templates and create `<component>_build` and `<component>_install` targets.

- `create_meson_stages(...)` — same idea for Meson projects; it produces setup/compile/install scripts using `tools/meson/*.in` templates.

## Helpers and utilities

- library_import_hint(out_var, lib_name [, prefix]) — builds a platform-correct shared-library or import-library filename (handles MSVC prefixes/suffixes).
- library_import_static_hint(out_var, lib_name [, prefix]) — builds canonical static library filename.
- library_dll_hint(out_var, lib_name [, prefix]) — MSVC-only helper for DLL filename under the install bindir.
- sanitize_for_filename(), list_join(), prepare_command() and other helpers used by templates and stage generators.

## Templates and implementation notes

-- CMake-stage templates: `tools/cmake/configure.cmake.in`, `tools/cmake/build.cmake.in`, `tools/cmake/install.cmake.in`.
  - The configure template runs cmake -S <src> -B <build> via the environment-aware runner and fails the configure step on non-zero exit.
  - The build template creates a `<component>_build` custom target that invokes the chosen build tool.
  - The install template creates a `<component>_install` custom target and declares installed artifacts as `OUTPUT` so consumers can depend on them.

-- Meson-stage templates: `tools/meson/setup.cmake.in`, `tools/meson/compile.cmake.in`, `tools/meson/install.cmake.in`.

## Examples

Simple mode (recommended for common use):

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

# After include you get imported targets and install wiring.
```

Advanced mode (explicit stages):

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

# Now you have 'mylib_build' and 'mylib_install' targets you can attach commands to:
add_custom_command(TARGET mylib_install POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E echo "Installed mylib")
```

### Dependent components

When an external component depends on another, use the dependant wrappers so Build Master will order configure/build stages automatically. The dependency argument should be one or more target names (for example `"b_install"`). The generated configure target for the dependant component will `add_dependencies()` on the provided targets.

Example: `liba` depends on `libb`.

```cmake
# Create and include libb first
create_cmake_component(B_FILE
                       libb
                       "LibB"
                       ${CMAKE_SOURCE_DIR}/thirdparty/libb
                       ${CMAKE_BINARY_DIR}/thirdparty/libb_build
                       "${options}"
                       shared
                       "")
include(${B_FILE})

# Create liba which depends on libb's install stage
create_cmake_dependant_component(A_FILE
                                 liba
                                 "LibA"
                                 ${CMAKE_SOURCE_DIR}/thirdparty/liba
                                 ${CMAKE_BINARY_DIR}/thirdparty/liba_build
                                 "${options}"
                                 shared
                                 ""  # no subcomponents
                                 "libb_install")
include(${A_FILE})
```

In this example the `liba` configure target will wait for `libb_install` before running, and `liba`'s imported targets will be wired after `libb` is installed.

## Why this matters

- Running configuration at configure time allows the parent CMake to inspect results, write find/import helpers, and update environment or search paths immediately. That avoids the deferred, opaque behavior caused by build-time configuration with `ExternalProject_Add`.
- Installing all third-party artifacts under a common `BUILDMASTER_INSTALL_DIR` simplifies consumption and linking from the parent project.

## Next steps / where to inspect

- High-level component helpers: `component/helpers.cmake`.
- CMake stage generator: `tools/cmake/helpers.cmake` and `tools/cmake/*.in`

## License

Build Master is distributed under the MIT License.  
See the LICENSE file for full details.
