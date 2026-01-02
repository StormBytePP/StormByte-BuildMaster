# StormByte‑BuildMaster  
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macos-blue)
![CMake](https://img.shields.io/badge/cmake-%3E%3D3.20-blue)
![Status](https://img.shields.io/badge/status-active-success)
![Type](https://img.shields.io/badge/type-build%20engine-lightgrey)

StormByte‑BuildMaster provides a modular, reproducible build system designed to overcome the limitations of CMake’s `ExternalProject_Add` and the challenges of integrating heterogeneous build systems during *configure time*.  
Traditional approaches make it difficult to propagate environment variables coherently—such as `PKG_CONFIG_PATH`, `LIB`, `INCLUDE`, or platform‑specific search paths—leading to inconsistent builds and fragile toolchain behavior.

This engine generates a hermetic, cross‑platform environment layer that ensures every tool (CMake, Meson, Ninja, Git, pkgconf, etc.) runs with a consistent and fully controlled environment.

---

## Table of Contents
- [Overview](#overview)  
- [Design Goals](#design-goals)  
- [Architecture](#architecture)  
- [Environment Layer](#environment-layer)  
- [Tools Layer](#tools-layer)  
- [Helper Functions](#helper-functions)  
- [Variables Propagated to Parent Scope](#variables-propagated-to-parent-scope)  
- [Usage](#usage)  
- [Platform Notes](#platform-notes)  
- [License](#license)

---

## Overview

StormByte‑BuildMaster is a **build environment generator**, not a wrapper.  
It prepares:

- isolated environment runner scripts  
- toolchain‑aware command invocations  
- reproducible build directories  
- patch/reset/switch scripts for Git  
- CMake/Meson/Ninja invocation scripts  
- consistent environment propagation across nested CMake scopes  

It can be embedded inside larger projects or used standalone as a build SDK.

---

## Design Goals

### 1. Deterministic configure‑time behavior  
CMake’s `ExternalProject_Add` defers configuration to *build time*, making it impossible to:

- modify environment variables before configuration  
- generate scripts that depend on configure‑time values  
- ensure reproducibility across platforms  

StormByte‑BuildMaster solves this by generating all scripts and environment wrappers during the *configure* phase.

### 2. Coherent environment propagation  
Meson, pkgconf, and other tools rely heavily on environment variables.  
This engine ensures:

- `PKG_CONFIG_PATH` is updated consistently  
- `PATH` is extended with install/bin directories  
- Windows `LIB` and `INCLUDE` variables are chained correctly  
- all tools run through a controlled environment runner  

### 3. Cross‑platform hermeticity  
The engine abstracts away:

- Windows vs. Unix shell differences  
- quoting and argument tokenization  
- executable permissions  
- path normalization  

### 4. Modularity  
Each subsystem (env, cmake, git, meson, ninja, pkgconf) is isolated and self‑contained.

---

## Architecture

StormByte‑BuildMaster is composed of three main layers:

### 1. Core Initialization  
Defined in `init_vars.cmake`, it establishes:

- source directories  
- binary directories  
- install prefixes  
- script output directories  

### 2. Environment Layer (`env/`)  
Responsible for:

- generating environment runner scripts  
- preparing tokenized command lists  
- updating environment variables  
- propagating environment state upward  

### 3. Tools Layer (`tools/`)  
Each tool (CMake, Git, Meson, Ninja, pkgconf) provides:

- initialization  
- helper functions  
- script generators  
- environment‑aware command wrappers  

---

## Environment Layer

The environment layer generates platform‑specific runner scripts:

### Linux/macOS
- `runner.sh`  
- `runner_silent.sh`

### Windows
- `runner.bat`  
- `runner_silent.bat`

These scripts:

- update `PKG_CONFIG`, `PKG_CONFIG_PATH`, `CFLAGS`, `CXXFLAGS`, `LDFLAGS`, `PATH`  
- ensure consistent environment chaining  
- execute arbitrary commands inside the prepared environment  

### Key Functions

#### `prepare_command(out list)`  
Converts a CMake list into a tokenized command suitable for `execute_process()`.

#### `update_env_runner()`  
Regenerates the environment runner script based on current variables.

---

## Tools Layer

Each tool has:

- an `init_vars.cmake`  
- a `helpers.cmake`  
- a `propagate_vars.cmake`  
- optional script templates (`*.in`)  

### CMake Tool  
Generates configure scripts for third‑party CMake projects.

### Git Tool  
Generates scripts for:

- applying patches  
- resetting repositories  
- switching branches  
- fetching updates  

### Meson Tool  
Prepares Meson invocations through the environment runner.

### Ninja Tool  
Provides environment‑aware Ninja commands.

### pkgconf Tool  
Ensures pkgconf is invoked with the correct environment.

---

## Helper Functions

The engine includes a rich set of helper functions:

- `windows_path()`  
- `library_import_hint()`  
- `library_import_static_hint()`  
- `sanitize_for_filename()`  
- `toggle_bool()`  
- `list_join()`  
- `ensure_build_dir()`  
- `prepare_command()`  

These functions abstract away quoting, path normalization, list handling, and directory creation.

---

## Variables Propagated to Parent Scope

StormByte‑BuildMaster exposes a set of variables to the parent CMake project using `PARENT_SCOPE`.

### Environment Variables

| Variable | Description |
|---------|-------------|
| `BUILDMASTER_SRC_DIR` | Root directory of the BuildMaster source |
| `BUILDMASTER_BIN_DIR` | Binary directory for generated scripts |
| `BUILDMASTER_SCRIPTS_DIR` | Base directory for generated scripts |
| `BUILDMASTER_INSTALL_DIR` | Install prefix used by all components |
| `BUILDMASTER_INSTALL_LIB_DIR` | Install lib directory |
| `BUILDMASTER_INSTALL_BIN_DIR` | Install bin directory |
| `BUILDMASTER_INSTALL_INCLUDE_DIR` | Install include directory |
| `ENV_RUNNER` | Tokenized command list for the environment runner |
| `ENV_RUNNER_SILENT` | Silent version of the environment runner |

### Tool Variables

| Variable | Description |
|---------|-------------|
| `ENV_CMAKE_COMMAND` | Environment‑aware CMake invocation |
| `ENV_CMAKE_SILENT_COMMAND` | Silent CMake invocation |
| `ENV_GIT_COMMAND` | Environment‑aware Git invocation |
| `ENV_MESON_COMMAND` | Environment‑aware Meson invocation |
| `ENV_NINJA_COMMAND` | Environment‑aware Ninja invocation |
| `PKG_CONFIG` | pkgconf executable (if found) |

---

## Usage

In your parent project:

```cmake
add_subdirectory(StormByte-BuildMaster)
include(StormByte-BuildMaster/helpers.cmake)

# Now you can use:
#   ${ENV_RUNNER}
#   ${ENV_CMAKE_COMMAND}
#   ${ENV_GIT_COMMAND}
#   ${ENV_MESON_COMMAND}
#   ${ENV_NINJA_COMMAND}
#   and all helper functions

## Platform Notes

### Windows
- `LIB` and `INCLUDE` are chained correctly  
- `.bat` runners ensure consistent environment propagation  
- quoting rules are handled automatically  

### Linux/macOS
- executable permissions are applied automatically  
- pkgconfig paths are merged safely  
- shell quoting is handled via `prepare_command()`  

---

## License

StormByte‑BuildMaster is licensed under the **MIT License**, allowing unrestricted use in external projects.
