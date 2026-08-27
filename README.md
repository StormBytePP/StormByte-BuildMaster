# StormByte BuildMaster

[![CI](https://github.com/StormBytePP/StormByte-BuildMaster/actions/workflows/ci.yml/badge.svg)](https://github.com/StormBytePP/StormByte-BuildMaster/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CMake ≥ 3.20](https://img.shields.io/badge/CMake-%E2%89%A5%203.20-064F8C)](https://cmake.org/)
[![CMake · Meson](https://img.shields.io/badge/backends-CMake%20%7C%20Meson-orange)](#how-a-component-works)
[![Linux · Windows · macOS](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)](#platform-notes)

A **declarative CMake DSL** for turning other people’s CMake and Meson
projects into first-class nodes in *your* graph.

You register components and edges in any order. BuildMaster materializes
stage targets, IMPORTED libraries, and link lines **once** — at the end of
the parent `CMAKE_SOURCE_DIR` — into a single install prefix, with a
toolchain and environment that actually reach nested Meson.

This is not a wrapper around `ExternalProject_Add`. It is not FetchContent
with extra macros. It is a small language for **graphs of third-party builds**.

---

## Why spend an afternoon on this

One well-behaved CMake library? `FetchContent` is enough.

Twelve upstreams — some CMake, some Meson, some that install `zsd.lib` when
you asked for `z.lib`, some that must configure *after* another prefix
exists, some that only work under `clang-cl`, and a static plugin pack the
linker will drop unless you wrap it in `--whole-archive` — and you already
have a private orchestration layer. Usually it is `add_custom_command`,
hardcoded paths, and “remember to declare ogg before vorbis”.

BuildMaster is that layer, written once:

| You stop writing… | You get… |
|-------------------|----------|
| “Declare A before B or configure explodes” | Order-independent registration |
| `ExternalProject` that configures at *build* time | Eager configure when the graph allows it |
| Hand-rolled Meson `setup` that misses `.pc` files | Same prefix, `PKG_CONFIG_PATH`, compilers, cache launchers |
| `POST_BUILD` rename scripts per MSVC flavor | Optional `RENAME` on the component |
| `--whole-archive` soup in the parent | `WHOLE` on a component or a **meta** collection |
| “Did anyone actually link this plugin?” | Orphan warnings at configure |
| Waiting on a slow tarball every `rm -rf build` | Point `BUILDMASTER_DOWNLOADSDIR` at a folder you keep |

The cost is a short public API. The payoff is a parent tree that looks like
a product, not a build blog.

---

## Table of contents

- [What it is](#what-it-is)
- [Comparison](#comparison)
- [Quick start](#quick-start)
- [Declarative model](#declarative-model)
- [How a component works](#how-a-component-works)
- [Dependencies and links](#dependencies-and-links)
- [Meta components](#meta-components)
- [Orphan warnings](#orphan-warnings)
- [Prerequisites](#prerequisites)
- [Component options](#component-options)
- [Whole-archive linking (`WHOLE`)](#whole-archive-linking-whole)
- [Build-only components and repack](#build-only-components-and-repack)
- [Subcomponent specs](#subcomponent-specs)
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
- [Supporting the project](#supporting-the-project)

---

## What it is

While the parent is still configuring, you **declare**:

- components (`create_cmake_component` / `create_meson_component` / headers
  variants / low-level `create_component`)
- collections (`create_meta_component` + `meta_component_add`)
- edges (`component_dependency`, `component_link`)
- optional work that must finish first (`component_prerequisite`, file and
  git helpers)

You do **not** `include()` generated fragments. You do **not** call a public
finalize. Materialization runs once via an internal `cmake_language(DEFER)`
at the end of `CMAKE_SOURCE_DIR`.

After that, each real component is a small machine:

```text
<id>_configure → <id>_build → <id>_install
         ↑
   <id>  (INTERFACE — this is what you link)
```

A **meta** uses the same anchor names (`<id>_install` waits on members) but
has no sources and installs nothing of its own.

Sources can be a git checkout, a cached tarball, a submodule, or any tree
you already have on disk.

Typical shapes: a bundled third-party stack, several bit-depth builds of
the same encoder that you later **repack**, a header-only SDK, a mixed
CMake + Meson graph on Linux / Windows / macOS, a plugin pack that a
larger library links as one `WHOLE` node.

---

## Comparison

| Capability | FetchContent | ExternalProject_Add | BuildMaster |
|------------|:------------:|:-------------------:|:-----------:|
| Fetch / manage sources | Yes | Yes | Yes (Git helpers) |
| Cacheable downloads | Partial | Manual | **Built-in** (`BUILDMASTER_DOWNLOADSDIR`) |
| Hash-verified downloads | Yes | Manual | **Yes**, plus reuse across builds |
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
| Build-only + static repack | No | Manual | **Yes** |
| Unified log API (`buildmaster_message`) | No | No | **Yes** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |
| Fail-fast after a stage failure | No | Manual | **Optional** |
| INTERFACE depends on `_install` | No | Manual | **Yes** |
| Orphan component / meta warning | No | No | **Yes** |
| Git reset + reconfigure (`buildmaster_clean`) | No | Manual | **Optional** |
| Per-repo post-install git reset | No | Manual | **Yes** |

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

No out-variable. No generated fragment to `include()`. Stage targets and
IMPORTED libraries appear when the parent `CMakeLists.txt` finishes.

Optional policy string (one trailing argument, never a pile of positionals):

```cmake
create_cmake_component(
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	${CMAKE_BINARY_DIR}/thirdparty/mylib_build
	"${_opts}"
	static
	"mylib"
	"INDENT=2;TOOLCHAIN=clang;RENAME;WHOLE"
)
```

Meson is the same shape with `create_meson_component`.

---

## Declarative model

1. **Register** components (order does not matter).
2. **Optional:** group them with `create_meta_component` /
   `meta_component_add` (`add` may run *before* `create`).
3. **Connect** with `component_dependency` and/or `component_link`
   (again, any order).
4. **Optional:** `component_prerequisite`, `file_download` /
   `file_download_cached` / `file_decompress`, or configure-time
   `create_git_*`.
5. End of `CMAKE_SOURCE_DIR`: BuildMaster materializes. Unused ids produce
   one **WARNING**.

| Nested configure | When |
|------------------|------|
| **Eager** | The component is not the `source` of any `component_dependency` — it can configure while the parent configures. |
| **Deferred** | It depends on another node — configure runs at build time under `<id>_configure`. |

That is the same behaviour you want by hand (consumer after producer)
without writing two APIs.

---

## How a component works

| Target | Role |
|--------|------|
| `<id>` | `INTERFACE`. Depends on `<id>_install`. **This is what you link.** |
| `<id>_configure` | Nested CMake or Meson setup |
| `<id>_build` | Compile |
| `<id>_install` | Install into `BUILDMASTER_INSTALL_DIR` (skipped for `BUILDONLY`) |
| produced libs | `STATIC` / `SHARED` **IMPORTED** files under the prefix (or the build dir) |

Library-mode installs list archive paths as `OUTPUT` so Ninja can depend on
real files, not empty stamps.

**Ids** become target and script names — keep them filesystem-friendly.
**Titles** may contain spaces; they only appear in status lines.

---

## Dependencies and links

### `component_dependency(source, dest)`

Order-only edge. At materialize time `dest` resolves as the first match:

1. Registered component id → `<id>_install`
2. Registered **meta** id → `<id>_install`
3. Name matching `*_install` / `*_configure` / `*_build`
4. Existing CMake target (prerequisite, `file_*`, your own custom target)

Otherwise: **FATAL_ERROR**.

Use this when you need *ordering* without a link line (headers-only producer,
a download that is not a library, a host target that writes files).

### `component_link(source, dest)`

Records a link on the component `INTERFACE`.

If `dest` is a graph node (component, meta, stage, or existing target),
BuildMaster also records `component_dependency`. A raw library spec
(`foo`, `vendor/foo`) does **not** get an automatic wait edge.

Host binaries are not graph nodes. Link them the ordinary way:

```cmake
target_link_libraries(MyApp PRIVATE mylib)
target_link_libraries(MyApp PRIVATE plugins)  # a meta
```

---

## Meta components

A **meta** is an `INTERFACE` plus a graph anchor. No sources, no compile,
no artifacts of its own. It collects members (components, other metas,
static or shared) and forwards wait + link. It may set `WHOLE` on the
collection even if members did not.

`TOOLCHAIN` on a meta does **not** compile the meta. At materialize time
that profile is copied onto members (and onto `component_dependency` /
`component_link` destinations whose source is the meta) that do not
already have `TOOLCHAIN` set. An explicit `TOOLCHAIN` on the child is
kept. Two metas inheriting **different** profiles onto the same empty
destination is **FATAL**.

`RENAME` and `BUILDONLY` on a meta are ignored with a warning (there is
nothing to install).

### Membership is not consumption

| Call | Meaning |
|------|---------|
| `meta_component_add(meta, member…)` | *Membership.* `member` belongs to `meta`. |
| `component_link` / `component_dependency` / host `target_link_libraries` **to the meta** | *Consumption.* Something actually needs the collection. |

If nothing consumes the meta, members are **not** built just because they
were added. That is deliberate: a plugin pack you forgot to link should not
silently compile half the tree.

`meta_component_add` may run before `create_meta_component`. Cycles
(`plugins → codecs → plugins`) are **FATAL**.

```cmake
meta_component_add(plugins zlib png)
create_meta_component(plugins "Plugin pack" "INDENT=1;WHOLE;TOOLCHAIN=clang")
component_link(engine plugins)
target_link_libraries(MyApp PRIVATE engine)
```

`zlib` and `png` compile as `clang` unless they already declared their
own `TOOLCHAIN`.

---

## Orphan warnings

After materialize, components and metas that were never consumed — no link,
no dependency, no host `target_link_libraries`, no **used** `component_repack`
— are listed in a single **WARNING**.

Membership in an *unused* meta does not count. A `BUILDONLY` phase that only
feeds an unused repack is still an orphan (and so is that repack).

---

## Prerequisites

```cmake
component_prerequisite(mylib my-unpack)
```

`<id>_configure` waits on an existing target: a download, an unpack, a
custom codegen step, anything CMake already knows.

That is how you keep “fetch the extra data, then configure the library”
declarative instead of a maze of `execute_process` in the parent.

---

## Component options

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
| Values | May contain spaces and extra `=` (`test==value` is fine) |
| `;` inside a value | Not allowed |
| Bare flag | `RENAME` / `WHOLE` / `BUILDONLY` ≡ `KEY=ON` |
| Unknown key | **WARNING**, ignored |
| Extra positional arguments | **FATAL_ERROR** |

| Key | Meaning |
|-----|---------|
| `INDENT` / `INDENT_LEVEL` | Tabs after the log header (non-negative integer) |
| `TOOLCHAIN` | Profile (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `RENAME` | Normalize archives to the declared name (install prefix, or build dir if `BUILDONLY`) |
| `WHOLE` | Whole-archive link of produced **static** archives |
| `BUILDONLY` | Do not install into the shared prefix |

---

## Whole-archive linking (`WHOLE`)

Static plugin-style archives often contain objects the linker will drop
unless the whole archive is forced in. Set `WHOLE` on the component or on
the meta that collects them.

One linear group per consumer (never nested `--whole-archive` sandwiches):

```text
-Wl,--whole-archive  A  B  -Wl,--no-whole-archive     # ELF
-Wl,-force_load,A  -Wl,-force_load,B                  # Mach-O
/WHOLEARCHIVE:A.lib  /WHOLEARCHIVE:B.lib              # MSVC
```

On shared, headers, or `BUILDONLY`, `WHOLE` is **ignored with a warning**.
A non-WHOLE library linked next to a WHOLE meta stays outside the group.

---

## Build-only components and repack

Some upstreams are not “the library you ship”. They are intermediate
static archives you later merge (several bit-depth builds, a main lib plus
an extra helper built from the same tree).

`BUILDONLY`:

- still has `_configure` / `_build` / `_install` anchors (`_install` is a
  coherence target — it does not publish to the shared prefix)
- artifacts live in **that component’s build directory**
- `RENAME` is allowed and runs against the build dir
- `component_link` *from a normal component to a BUILDONLY* is **FATAL**
  (you cannot link a tree that was never installed)

`component_repack(id title output inputs…)` merges listed archives with the
host archiver (`ar` / `llvm-ar` / `lib.exe` / `libtool`) into one file under
the shared prefix and exposes it as an IMPORTED target. Inputs may be
BUILDONLY components. The repack waits on each input’s **`_build`**, not
`_install`, so BUILDONLY works. A custom host target that only has artifacts
(no `_build`) is accepted as a corner case.

A repack that nothing consumes does **not** mark its inputs as used.

---

## Subcomponent specs

One component can produce several archives. List them on `create_*`:

| Spec | File | IMPORTED target |
|------|------|-----------------|
| `mylib` | `${BUILDMASTER_INSTALL_LIBDIR}/libmylib.a` | `mylib` |
| `vendor/foo/foolib` | `${BUILDMASTER_INSTALL_LIBDIR}/vendor/foo/libfoolib.a` | `vendor_foo_foolib` |

```cmake
library_import_static_hint(out name prefix [subdir])
library_import_hint(out name prefix [subdir])
```

A static `.a` does not pull sibling static archives. List every required
spec on the outermost component, or `component_link` them.

---

## Header-only components

`create_cmake_headers_component` / `create_meson_headers_component`:

- no IMPORTED archive
- install stamp under the include tree
- `INTERFACE` + `SYSTEM` include of `BUILDMASTER_INSTALL_INCLUDEDIR`

Useful for SDKs and for graphs that only need headers before a later
compile.

---

## Per-component toolchains

`TOOLCHAIN=` pins **that component** (and nested BuildMaster under it).
The parent job’s compiler does not change.

| Name | Drivers | Linker |
|------|---------|--------|
| `gcc` | `gcc` / `g++` | System default |
| `clang` | `clang` / `clang++` | LLD required on **Linux**; not forced on **macOS** |
| `clang-cl` | `clang-cl` | `lld-link` + `llvm-lib` (Windows) |
| `msvc` | `cl` | `link.exe` + `lib.exe` (Windows) |

Unknown names fail at configure and list known profiles. Nested Meson
always receives the matching native file
(`BUILDMASTER_MESON_NATIVE_FILE`), including when the profile is inherited.
That keeps ccache/sccache keys coherent.

---

## Recursive usage

An external CMake project may `add_subdirectory(buildmaster)` again.
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses the
install root, markers, scripts, and log level.

Pass the repo root if the nested project must find BuildMaster:

```cmake
create_cmake_component(
	nest
	"Nested graph"
	${NEST_SRC}
	${NEST_BUILD}
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"vendor/nest/nestlib;vendor/nest/midlib"
)
```

---

## Logging

All BuildMaster diagnostics go through one API. **Do not use CMake
`message()`** in a project that uses BuildMaster (and never inside
BuildMaster itself, except `log.cmake`). Raw `message()` ignores
`BUILDMASTER_LOGLEVEL` and breaks the aligned headers.

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

`USER` is reserved for **your** project (header label `User`). Use it for
lines such as “Setting up the library”, not an internal name like `CMake`.

```cmake
buildmaster_message(USER STATUS "Setting up the library" 1)
buildmaster_message(USER INFO  "extra data already cached" 2)
buildmaster_message(USER FATAL "extra data hash missing")
```

```text
-- [BuildMaster/User     ]: 	Setting up the library
-- [INFO    ][BuildMaster/User     ]: 		extra data already cached
```

### Levels

Higher number = quieter filter threshold:

| Level | Role |
|-------|------|
| `LOWLEVEL` | Function enter/exit and path plumbing |
| `DEBUG` | Useful when debugging BuildMaster or a consumer graph |
| `INFO` | Optional progress (rename skip, unpack OK) |
| `WARNING` | Shown at `INFO` or more verbose; hidden at `STATUS` and `FATAL` |
| `STATUS` | Default. Stage titles (`Configuring` / `Compiling` / `Installing`) |
| `FATAL` | Always printed. Stops configure/script. Never filtered |

`BUILDMASTER_LOGLEVEL=FATAL` is the quietest user setting. Allowed;
discouraged.

An unknown level (typo `DEHBUG`) is **FATAL** and lists accepted names.

### Filter

A line is printed when its level number is **≥** the current
`BUILDMASTER_LOGLEVEL`, except:

- `FATAL` is never dropped
- `WARNING` is dropped when the current level is stricter than `INFO`

### Format

- Header is never indented. Tabs apply only to the body.
- `STATUS`: `[BuildMaster/<Module>]: <tabs><text>`
- Any other level: `[<LEVEL>][BuildMaster/<Module>]: <tabs><text>` (no space
  between the two brackets)
- `<LEVEL>` is uppercase, padded to `LOWLEVEL`
- `<Module>` is CamelCase, padded to `Toolchain`

Ninja `COMMENT` strings use the same `STATUS` header so stage lines line
up with configure output.

### Selecting the level

```bash
export BUILDMASTER_LOGLEVEL=DEBUG
# or
cmake -DBUILDMASTER_LOGLEVEL=INFO …
```

Default is `STATUS`. `BUILDMASTER_DEBUG` is **ignored**.

Change the level and **re-run CMake** so generated `-P` scripts see it.

### Built-in modules

| Key | Header | Typical owner |
|-----|--------|---------------|
| `ARCHIVE` | Archive | Static merge / archiver |
| `CMAKE` | CMake | CMake stages |
| `COMPONENT` | Component | Factory / graph |
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

Unknown module keys are **FATAL**.

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
stdout on success and dump it on failure (Unix shell and Windows PowerShell).

| LOGLEVEL | VERBOSE | BuildMaster lines | Compile lines |
|----------|---------|-------------------|---------------|
| `STATUS` | off | Stage titles | Quiet |
| `DEBUG` | off | Graph + git + paths | Quiet |
| `STATUS` | on | Stage titles | Live + `--verbose` / `-v` |
| `LOWLEVEL` | on | Everything | Live + `--verbose` / `-v` |

---

## Fail-fast

A non-zero nested build/install fails that stage. The INTERFACE target
depends on `<id>_install`, so the parent does not compile against a
half-empty prefix.

Optional markers:

```bash
export BUILDMASTER_FAIL_FAST=1
```

| Value | Behaviour |
|-------|-----------|
| **ON** | First failure writes markers; later stages skip and fail |
| **OFF** (default) | Independent components can continue (cache warm) |

---

## Compiler cache

If the parent sets `CMAKE_C_COMPILER_LAUNCHER` /
`CMAKE_CXX_COMPILER_LAUNCHER` and/or `CCACHE_DIR` / `SCCACHE_DIR`,
BuildMaster forwards them to env runners, child CMake, and Meson native
files.

On Windows, launchers are **not** folded into `CC` / `CXX`.

---

## Platform notes

| Topic | Linux | Windows | macOS |
|-------|-------|---------|-------|
| Env runner | `runner.sh` | PowerShell (`runner_silent.ps1`) | same as Linux |
| Static merge | GNU `ar` / `llvm-ar` | `lib /OUT:` | `libtool -static` |
| Meson PDB | — | `/Z7` | — |
| `TOOLCHAIN=clang` | LLD required | use `clang-cl` | LLD not forced |
| `TOOLCHAIN=msvc` / `clang-cl` | invalid | supported | invalid |

AppleClang is treated as the **clang** family for toolchain swap tests and
profile selection.

---

## Git helpers

Bound to a **component id**. Configure-time ops run when you call them;
a post-install reset can restore the tree after patching.

```cmake
create_git_reset_file(mylib "MyLib reset" ${MYLIB_SRC_DIR})
create_git_patch_file(mylib "MyLib patch" ${MYLIB_SRC_DIR} ${PATCH_FILE})
create_git_switch_branch(mylib "MyLib branch" ${MYLIB_SRC_DIR} my-topic)
create_git_fetch(mylib "MyLib fetch" ${MYLIB_SRC_DIR})
```

`buildmaster_clean` resets registered git roots and is meant to be followed
by a reconfigure. `buildmaster_git_post_install_marker_for_srcdir` resolves
the reset script path for a source tree.

---

## File download and decompress

CMake can already hash a download. What it does not give you for free is a
**stable cache** that survives `rm -rf build`.

Default destination is `${BUILDMASTER_BINDIR}/downloads`. Point
`BUILDMASTER_DOWNLOADSDIR` at a folder *outside* the build tree and the
same URL + hash is reused on the next configure. No extra `if(EXISTS)`, no
hand-rolled stamp files.

```bash
# Keep tarballs across wipe-and-rebuild
export BUILDMASTER_DOWNLOADSDIR="$HOME/.cache/buildmaster/downloads"
# or
cmake -DBUILDMASTER_DOWNLOADSDIR=/var/cache/buildmaster/downloads …
```

A slow extra-data tarball from a far-away host should not be the reason you
wait before you can compile *your* code again. The first run pays the
network; every run after that is a hash check against a file you already
have.

| Function | Role |
|----------|------|
| `file_download_cached` | Reuse the file when the hash matches; download only on miss or mismatch |
| `file_download` | Always download, retry, verify hash |
| `file_decompress` | `file(ARCHIVE_EXTRACT)` into a directory you choose |
| `file_checksum_correct` | Hash helper used by the cached path |

```cmake
file_download_cached(my-data
	"https://example.com/data.tar.gz"
	TITLE "Example data"
	EXPECTED_HASH "SHA256=${HASH}"
)
include(${my-data})

file_decompress(my-unpack
	"${BUILDMASTER_DOWNLOADSDIR}/data.tar.gz"
	${UNPACK_DIR}
	TITLE "Example data"
)
include(${my-unpack})

component_prerequisite(mylib my-unpack)
```

Paths are checked against `..` traversal. Wire the resulting targets into
the graph with `component_prerequisite` or `component_dependency`.

---

## API map

| Area | Commands |
|------|----------|
| Components | `create_cmake_component`, `create_meson_component`, `create_cmake_headers_component`, `create_meson_headers_component`, `create_component` |
| Graph | `component_dependency`, `component_link`, `component_prerequisite` |
| Meta | `create_meta_component`, `meta_component_add` |
| Repack | `component_repack` |
| Files | `file_download`, `file_download_cached`, `file_decompress`, `file_checksum_correct` |
| Git | `create_git_reset_file`, `create_git_patch_file`, `create_git_switch_branch`, `create_git_fetch`, `buildmaster_git_post_install_marker_for_srcdir` |
| Log | `buildmaster_message` |
| Paths / import | `ensure_build_dir`, `library_import_hint`, `library_import_static_hint`, `sanitize_for_filename`, `buildmaster_parse_subcomponent` |
| Toolchain | `buildmaster_validate_toolchain`, `buildmaster_load_toolchain_profile`, `buildmaster_find_archiver` |
| Options | `buildmaster_parse_component_options` |

Stage generators (`create_cmake_stages` / `create_meson_stages`) are
**internal**. The supported surface is `create_*_component`.

---

## Self-tests

A synthetic harness lives under `.github/tests/` (not part of the DSL
runtime). It has no real third-party projects.

| You added… | Update |
|------------|--------|
| Public function or macro | `.github/tests/expected/public_functions.txt` |
| Propagated / toolchain-exported variable | `.github/tests/expected/propagated_vars.txt` |
| Dependant graph edge | `.github/tests/expected/dependant_edges.txt` |
| Smoke install artifact | `.github/tests/expected/smoke_artifacts.txt` |

Do not hardcode new assertions in `.github/workflows/ci.yml`.

```bash
cmake -S .github/tests/harness -B build/harness -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/harness --target run_buildmaster_checks
cmake --build build/harness --target run_buildmaster_smoke
```

---

## License

MIT. See [LICENSE](LICENSE).

---

## Supporting the project

BuildMaster is free software. If it saves you a weekend of glue code — or
if you use it together with the rest of the StormByte stack — voluntary
support helps keep maintenance and CI going.

PayPal: [StormByte@gmail.com](mailto:StormByte@gmail.com)

If you prefer another channel (bank transfer, sponsorship of a specific
issue, or something that fits your organisation), write to the same
address and we will find a workable option. There is no obligation; the
license does not change either way.
