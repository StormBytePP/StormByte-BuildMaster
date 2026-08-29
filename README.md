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

The public surface is eighteen `buildmaster_*` commands. Everything else
is `_bm_<craft>_*` and is not a supported API. Coming from 1.0.x?
[`MIGRATE.md`](MIGRATE.md).

---

## Why spend an afternoon on this

One well-behaved CMake library? `FetchContent` is enough.

Twelve upstreams — some CMake, some Meson, some that install `zsd.lib` when
you asked for `z.lib`, some that must configure *after* another prefix
exists, some that only work under `clang-cl`, and a static plugin pack the
linker will drop unless you wrap it in `--whole-archive` — and you already
have a private orchestration layer. Usually it is `add_custom_command`,
hardcoded paths, and “remember to declare zlib before libpng”.

BuildMaster is that layer, written once:

| You stop writing… | You get… |
|-------------------|----------|
| “Declare A before B or configure explodes” | Order-independent registration |
| `ExternalProject` that configures at *build* time | Eager configure when the graph allows it |
| A link *and* a matching wait edge | `buildmaster_link` already waits |
| “Is this CMake or Meson?” in every wrapper | `buildmaster_component` looks at `srcdir` |
| Hand-rolled Meson `setup` that misses `.pc` files | Same prefix, `PKG_CONFIG_PATH`, compilers, cache launchers |
| `POST_BUILD` rename scripts per MSVC flavor | Optional `RENAME` on the component |
| `--whole-archive` soup in the parent | `WHOLE` on a component or a **meta** collection |
| `LNK2005` / duplicate `.res` after `/WHOLEARCHIVE` | `STRIPRES` on static MSVC/clang-cl archives (default on) |
| `shlwapi` on every consumer because a static `.lib` does not record it | Optional `LINK={…}` on the producer (or the meta) |
| `/FORCE:MULTIPLE` / `-Bsymbolic` on the parent because the WHOLE pack needs it | Optional `LINKFLAGS={WINDOWS={…};UNIX={…}}` on the producer |
| Hand-written `.pc` so the next Meson node finds this prefix | Optional helper `PC={…}` on the component |
| `cmake_language(DEFER)` so a summary line appears *after* the graph | Optional **hooks** |
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
- [Raw system libraries (`LINK`)](#raw-system-libraries-link)
- [Raw linker flags (`LINKFLAGS`)](#raw-linker-flags-linkflags)
- [Meta components](#meta-components)
- [Hooks](#hooks)
- [Orphan warnings](#orphan-warnings)
- [Prerequisites](#prerequisites)
- [Component options](#component-options)
- [Whole-archive linking (`WHOLE`)](#whole-archive-linking-whole)
- [Stripping `.res` members (`STRIPRES`)](#stripping-res-members-stripres)
- [Helper pkg-config files (`PC`)](#helper-pkg-config-files-pc)
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

- components (`buildmaster_component`)
- collections (`buildmaster_meta` + `buildmaster_meta_add`)
- edges (`buildmaster_depend`, `buildmaster_link`)
- hooks (`buildmaster_hook_component`, `buildmaster_hook_graph`)
- optional work that must finish first (`buildmaster_prerequisite`,
  file and git helpers)

You do **not** `include()` generated fragments. You do **not** call a
public finalize. Materialization runs once via an internal
`cmake_language(DEFER)` at the end of `CMAKE_SOURCE_DIR`.

After that, each real component is a small machine:

```text
<id>_configure → <id>_build → <id>_install
         ↑
   <id>  (INTERFACE — this is what you link)
```

A **meta** uses the same anchor names (`<id>_install` waits on members)
but has no sources and installs nothing of its own.

Sources can be a git checkout, a cached tarball, a submodule, or any
tree you already have on disk.

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
| Download / unpack during parent configure | Manual | No | **Yes** (`buildmaster_download*`) |
| Declarative graph (order-independent) | No | No | **Yes** |
| Backend chosen by the caller | N/A | Manual | **Inferred from `srcdir`** |
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
| Strip `.res` from static MSVC archives | Manual `/REMOVE` | Manual | **Default on static (`STRIPRES`)** |
| Raw system libs on the INTERFACE | Manual on every consumer | Manual | **Optional (`LINK={…}`)** |
| Raw linker flags on the INTERFACE | Manual on every consumer | Manual | **Optional (`LINKFLAGS={…}`)** |
| Helper `.pc` for the shared prefix | Manual | Manual | **Optional (`PC={…}`)** |
| Build-only + static repack | No | Manual | **Yes** |
| Unified log API (`buildmaster_message`) | No | No | **Yes** |
| Safe recursive nesting | Fragile | Fragile | **Designed for it** |
| Fail-fast after a stage failure | No | Manual | **Optional** |
| INTERFACE depends on `_install` | No | Manual | **Yes** |
| Orphan component / meta warning | No | No | **Yes** |
| Inspectable post-graph hooks | Manual `DEFER` | Manual | **Yes** |
| Per-repo post-install git reset | No | Manual | **Yes** |

---

## Quick start

```cmake
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")  # optional

add_subdirectory(path/to/buildmaster)

buildmaster_message(STATUS "Setting up My Library" 1)

set(_opts "-DENABLE_FOO=ON")
buildmaster_component(
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	"${_opts}"
	shared
	"mylib"
)

target_link_libraries(MyApp PRIVATE mylib)
```

No out-variable. No generated fragment to `include()`. No extra
`include(helpers.cmake)` after `add_subdirectory`. Stage targets and
IMPORTED libraries appear when the parent `CMakeLists.txt` finishes.

`srcdir` must contain exactly one of `CMakeLists.txt` or `meson.build`.
You do not pick the backend.

Optional policy string (one trailing argument, never a pile of
positionals):

```cmake
buildmaster_component(
	mylib
	"My Library"
	${CMAKE_SOURCE_DIR}/thirdparty/mylib
	"${_opts}"
	static
	"mylib"
	"INDENT=2;TOOLCHAIN=clang-cl;RENAME;WHOLE;LINK={shlwapi;ws2_32};PC={VERSION=1.2.3;NAME=mylib}"
)
```

On a static MSVC / clang-cl archive, `STRIPRES` is already on. You only
write it when you want it off (`STRIPRES=OFF`).

The build-directory slot is optional. Omit it and BuildMaster uses
`${CMAKE_CURRENT_BINARY_DIR}/bm/<id>`. If you still pass a path, that
path is used as-is.

Factory `options` may also be a CMake list of neutral keys
(`CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS`, `INCLUDES`,
`DEFINITIONS`). Those append to the parent job / toolchain and stay
**private** to the nested compile. They are not `ENV{CFLAGS}`.

---

## Declarative model

1. **Register** components (order does not matter).
2. **Optional:** group them with `buildmaster_meta` /
   `buildmaster_meta_add` (`add` may run *before* `buildmaster_meta`).
3. **Connect** with `buildmaster_depend` and/or `buildmaster_link`
   (again, any order).
4. **Optional:** hooks, `buildmaster_prerequisite`,
   `buildmaster_download*` / `buildmaster_decompress` (these run
   during the call, so sources exist before the factory), or
   configure-time `buildmaster_git_*`.
5. End of `CMAKE_SOURCE_DIR`: BuildMaster materializes. Unused ids
   produce one **WARNING**. Hooks run after that pass.

| Nested configure | When |
|------------------|------|
| **Eager** | The component is not the `source` of any recorded wait edge — it can configure while the parent configures. |
| **Deferred** | It must wait on another node — configure runs at build time under `<id>_configure`. |

A tarball you unpack in the same `CMakeLists.txt` as the factory does
**not** need a dependency edge for the first configure: the files are
already on disk. Add `buildmaster_depend` /
`buildmaster_prerequisite` only when a *later rebuild* of that file
target must precede configure.

---

## How a component works

| Target | Role |
|--------|------|
| `<id>` | `INTERFACE`. Depends on `<id>_install`. **This is what you link.** |
| `<id>_configure` | Nested CMake or Meson setup |
| `<id>_build` | Compile |
| `<id>_install` | Install into `BUILDMASTER_INSTALL_DIR` (skipped for `BUILDONLY`) |
| produced libs | `STATIC` / `SHARED` **IMPORTED** files under the prefix (or the build dir) |

Library-mode installs list archive paths as `OUTPUT` so Ninja can
depend on real files, not empty stamps.

**Ids** become target and script names — keep them filesystem-friendly.
**Titles** may contain spaces; they only appear in status lines.

The `INTERFACE` stub exists as soon as you call
`buildmaster_component`. You may `add_library(Vendor::Foo ALIAS foo)`
in the same file. Produced paths are filled in at materialize.

---

## Dependencies and links

### `buildmaster_depend(source, dest)`

Order-only edge. At materialize time `dest` resolves as the first match:

1. Registered component id → `<id>_install`
2. Registered **meta** id → `<id>_install`
3. Name matching `*_install` / `*_configure` / `*_build`
4. Existing CMake target (prerequisite, download, your own custom target)

Otherwise: **FATAL_ERROR** — unless the same pair is also a
`buildmaster_link` to a library spec or an on-disk archive. That dest
is link-only: there is no wait target.

Use this when you need *ordering* without a link line (headers-only
producer, a download that is not a library, a host target that writes
files).

A second explicit call with the same `(source, dest)` is **WARNING**
and a no-op. That includes “I already `buildmaster_link`’d this pair”.
The warning is for you. Unresolvable dest at finalize stays **FATAL**.

### `buildmaster_link(source, dest)`

Records a link on the component `INTERFACE`.

`dest` is a **BuildMaster graph node**: another component, a meta, an
existing CMake target, an archive that already exists on disk, or a
library spec (`<name>` / `<subdir>/<name>`) under the BM prefix.

**Link already waits.** Every `buildmaster_link(A B)` records the same
order-only edge as `buildmaster_depend(A B)`, even if `B` is
registered later in the file. You do not add a second
`buildmaster_depend(png zlib)` unless you enjoy the warning.

A spec or an on-disk archive stays **link-only** (no wait target).
Raw system libraries do **not** belong here — that is `LINK=`.

---

## Raw system libraries (`LINK`)

A static archive does not “contain” `shlwapi`. The `.obj` files inside
it have unresolved imports, and the linker of **your** DLL is the one
that has to see `shlwapi.lib`. Repeating that on every consumer is how
the line rots.

`LINK` is the declaration on the **producer** (or on a meta that groups
producers): whoever links this `INTERFACE` also links these names.

```cmake
buildmaster_component(
	dbclient
	"DB client"
	${CLIENT_SRCDIR}
	"${CLIENT_OPTIONS}"
	static
	"dbclient"
	"INDENT=1;LINK={shlwapi;ws2_32;advapi32}"
)

target_link_libraries(MyDatabase PRIVATE dbclient)
```

CMake then carries `shlwapi` through the chain to `MyDatabase.dll`.
You did not repair the upstream CMake. You told the BM target the
truth about what a consumer of that target must pass to the linker.

| Form | Meaning |
|------|---------|
| omitted | nothing extra |
| `LINK=shlwapi` | one raw linker name |
| `LINK={shlwapi;ws2_32}` | several — `;` inside `{…}` is not a pair break |
| `LINK=` / bare `LINK` | **FATAL** |
| several items without braces | **FATAL** |

Items are **external to BuildMaster**. They go to the linker as written.
They are not component ids, not metas, not CMake targets, and not specs
under the install prefix. A name that collides with an existing
`TARGET` may be resolved by CMake as that target — do not pick
colliding names.

This does **not** fix a program that links the third-party archive
without going through the BM `INTERFACE`. If someone runs
`lld-link … dbclient.lib` by hand, `LINK` does not exist. That is the
point of the contract, not a bug.

Headers mode has no link line: `LINK` is **INFO**, ignored.
A meta **accepts** `LINK` and puts the names on the collection
`INTERFACE`, so you declare the syslibs once instead of on every member.

`LINK_EXTRA` from 1.x is gone. Same idea, shorter name, no graph
confusion. Using the old key is a **WARNING**.

---

## Raw linker flags (`LINKFLAGS`)

`LINK=` is a *library name*. `LINKFLAGS=` is a *flag* the linker
understands (`/FORCE:MULTIPLE`, `-Wl,-Bsymbolic`). Same INTERFACE,
same propagation: whoever links this id also gets those
`target_link_options`.

This is a sharp tool. Flags on a leaf you later link from the
application **will** reach that application. If `-Bsymbolic` on a
codec pack would poison the final `.so`, do not put it on a node the
app links. Put it on a `BUILDONLY` leaf you only feed to
`buildmaster_repack`, or keep it off BuildMaster.

| Form | Meaning |
|------|---------|
| omitted | nothing extra |
| `LINKFLAGS=-Wl,-Bsymbolic` | one flag, every OS |
| `LINKFLAGS={WINDOWS={/FORCE:MULTIPLE};UNIX={-Wl,-Bsymbolic}}` | per-platform groups |
| `LINKFLAGS=` / bare `LINKFLAGS` | **FATAL** |

Groups (names are deliberate — not CMake’s `WIN32` / `APPLE`):

| Group | When it applies |
|-------|-----------------|
| `WINDOWS` | Windows |
| `LINUX` | Linux |
| `MAC` | macOS |
| `UNIX` | Linux **and** macOS |

A group that does not apply is skipped at **INFO**. An unknown group
name is **FATAL**. Headers mode: **WARNING**, ignored. A meta accepts
`LINKFLAGS` the same way it accepts `LINK`.

---

## Meta components

```cmake
buildmaster_meta(plugins "Plugin pack" "WHOLE;TOOLCHAIN=msvc")
buildmaster_meta_add(plugins codec-a codec-b)
buildmaster_link(engine plugins)
```

No sources, no install of its own. `<id>_install` waits on members.
`TOOLCHAIN` on the meta copies onto members (and onto empty dests)
that do not already have one. Two metas fighting over the same empty
dest is **FATAL**. `PC={…}` on a meta is **FATAL**.

`buildmaster_meta_add` may run before `buildmaster_meta`.

---

## Hooks

A function you already defined, fired after materialize, with an
**alias** that is the only order key (ASCII ascending). `CAPTURE`
snapshots variables **by copy** into the generated script.

```cmake
function(print_enabled_flags)
	buildmaster_message(STATUS "enabled: ${CAPTURED_FLAGS}")
endfunction()

buildmaster_hook_component(engine print_enabled_flags zz
	CAPTURE CAPTURED_FLAGS "${ENGINE_FLAGS}")
buildmaster_hook_graph(print_enabled_flags summary)
```

`fn` must exist at registration — missing function is a friendly
FATAL, not CMake’s trace. An id that never materializes is FATAL.
There is **no** guarantee beyond alias order: project layout decides
when a given id is walked.

---

## Orphan warnings

A registered component or meta that nothing links and nothing waits
on produces one **WARNING** after materialize. That is the “did
anyone actually use this plugin?” line. Fix the graph or accept the
noise.

---

## Prerequisites

`buildmaster_prerequisite(id target)` waits on a host / download /
custom target before `<id>_configure`. Use it for
`buildmaster_download_cached` names, not for other components
(`buildmaster_depend` / `buildmaster_link` already cover those).

---

## Component options

One optional trailing `KEY=value;…` on `buildmaster_component` /
`buildmaster_meta`.

| Key | Default | Notes |
|-----|---------|--------|
| `INDENT` / `INDENT_LEVEL` | `0` | Tabs after the log header |
| `TOOLCHAIN` | inherit | `gcc`, `clang`, `clang-cl`, `msvc` |
| `RENAME` | ON | Canonical archive name after install |
| `WHOLE` | OFF | Whole-archive link of **static** produced archives |
| `BUILDONLY` | OFF | Do not publish into the shared prefix |
| `STRIPRES` | ON | Strip `*.res` from static MSVC / clang-cl archives after `RENAME` |
| `PC={…}` | off | Helper `.pc` for **this** prefix |
| `LINK=` / `LINK={…}` | empty | Raw system linker names |
| `LINKFLAGS=` / `LINKFLAGS={…}` | empty | Raw linker flags, optional platform groups |

Unknown keys: **WARNING**, ignored. Extra positionals: **FATAL**.
`;` inside `{…}` is not a pair break.

---

## Whole-archive linking (`WHOLE`)

Static archives the linker would otherwise drop (plugin object files
with no referenced root symbol). One linear group per consumer
(ELF / Mach-O / MSVC). Put it on the leaf or on the meta you link.

---

## Stripping `.res` members (`STRIPRES`)

Default **ON** for static MSVC / clang-cl archives. After `RENAME`,
`lib` / `llvm-lib` `/LIST` + `/REMOVE` of `*.res`. Silent no-op on
other toolchains. Shared / headers: warning, ignored.

Without this, `/WHOLEARCHIVE` on a static MSVC lib often dies with
`LNK2005` on duplicate resources.

---

## Helper pkg-config files (`PC`)

This is **not** a replacement for a real upstream `.pc`. It exists so
**later components in the same BuildMaster prefix** can find this
library without you writing a `file(WRITE …)` after install.

```cmake
buildmaster_component(
	zlib "zlib" ${ZLIB_SRC} "${ZLIB_OPTS}" static "z"
	"PC={VERSION=1.3.1;NAME=zlib;DESCRIPTION=zlib compression}")
buildmaster_component(
	png "libpng" ${PNG_SRC} "${PNG_OPTS}" static "png"
	"PC={VERSION=1.6.43;NAME=libpng}")
buildmaster_link(png zlib)
```

After install:

```text
${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/zlib.pc
${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/libpng.pc   # Requires: zlib
```

`prefix` / `libdir` / `includedir` are the **BuildMaster install
tree**. A portable distro `.pc` is out of scope.

| Inner key | Required | Default |
|-----------|:--------:|---------|
| `VERSION` | when enabled | — **FATAL** if missing |
| `NAME` | no | First produced spec basename, else the component id |
| `DESCRIPTION` | no | Component title |
| `ENABLED` | no | `TRUE`. `ENABLED=FALSE` skips the file and does not require `VERSION` |

`Requires` comes from direct `buildmaster_link` destinations that
themselves have PC enabled (one hop, no metas). Collision with an
upstream `.pc` at the same path is **FATAL**. `BUILDONLY` + enabled
PC is **FATAL**. Meta + `PC` is **FATAL**. Bare `PC` / `PC=ON` is
**FATAL**.

---

## Build-only components and repack

Some upstreams are not “the library you ship”. They are intermediate
static archives you later merge. Mark them `BUILDONLY`: they compile
into the component build dir and never enter the shared prefix.
`buildmaster_repack` then publishes one archive from those inputs.

A `BUILDONLY` component is not a link dest (`buildmaster_link` to it
is **FATAL**). Wait on its stages with `buildmaster_depend`, or
consume it only as a repack input.

---

## Subcomponent specs

Produced libraries are `<name>` or `<subdir>/<name>`. The install
layout keeps the subdirectory. `buildmaster_link` accepts the same
spec form when the dest is not a registered id — the archive need
not exist at configure. Stage `OUTPUT` lists the specs declared on
the factory.

---

## Header-only components

```cmake
buildmaster_component(
	foo-headers
	"Foo headers"
	${FOO_SRC}
	"${FOO_OPTS}"
	headers
)
```

Configure / build / install still run for the include tree. There is
no produced archive and no link line. `LINK` is **INFO**, ignored.
`LINKFLAGS` is **WARNING**, ignored.

---

## Per-component toolchains

| Profile | Compilers | Notes |
|---------|-----------|-------|
| `gcc` | `gcc` / `g++` | System default |
| `clang` | `clang` / `clang++` | LLD required on **Linux**; not forced on **macOS** |
| `clang-cl` | `clang-cl` | `lld-link` + `llvm-lib` (Windows) |
| `msvc` | `cl` | `link.exe` + `lib.exe` (Windows) |

Unknown names fail at configure and list known profiles. Nested Meson
always receives the matching native file.

---

## Recursive usage

An external CMake project may `add_subdirectory(buildmaster)` again.
BuildMaster initializes **once** (`BUILDMASTER_CONFIGURED`) and reuses
the install root, markers, scripts, and log level.

Third-party trees that themselves vendor BuildMaster must sit as
**sibling directories** of the BuildMaster checkout the parent added.

The nested graph speaks with `buildmaster_message` like the parent.
Under the default silent runner those lines are replayed **live**.

---

## Logging

All BuildMaster diagnostics go through one API. **Do not use CMake
`message()`** in a project that uses BuildMaster (and never inside
BuildMaster itself, except `log.cmake`).

### `buildmaster_message`

```cmake
buildmaster_message(<level> "<text>" [<indent>])
```

Module is always **`USER`**. There is no parameter to override it.

```cmake
buildmaster_message(STATUS "Setting up the library" 1)
buildmaster_message(INFO  "extra data already cached" 2)
buildmaster_message(FATAL "extra data hash missing")
```

```text
-- [BuildMaster/User     ]:	Setting up the library
-- [INFO    ][BuildMaster/User     ]:		extra data already cached
```

Internals use `_bm_log_message(<module> <level> "<text>" [<indent>])`.
A consumer that passes a module name is calling the old arity and
will explode (`CORE` is not a log level).

### Levels

| Level | Role |
|-------|------|
| `LOWLEVEL` | Function enter/exit and path plumbing |
| `DEBUG` | Useful when debugging BuildMaster or a consumer graph |
| `INFO` | Policy that was ignored because it cannot apply |
| `WARNING` | Something you should fix. **Always printed.** |
| `STATUS` | Default narrative |
| `FATAL` | Always printed. Stops configure/script |

Default `BUILDMASTER_LOGLEVEL` is `STATUS`. `WARNING` and `FATAL`
ignore the filter. Without `BUILDMASTER_VERBOSE`, a WARNING is one
yellow `message(NOTICE)` line (no `CMake Warning at …` banner).
With verbose, `message(WARNING)`.

`BUILDMASTER_DEBUG` is ignored.

### Nested / recursive lines

The **silent** runner keeps the full child log and reprints
`[BuildMaster/…]` lines live so a long nested configure does not
look hung. On child failure the runner dumps the **entire** log.

---

## Verbosity of tool output

`BUILDMASTER_VERBOSE` is independent of the log level. It selects the
**runner**, not which BM lines exist.

| `BUILDMASTER_VERBOSE` | Runner | What you see |
|-----------------------|--------|----------------|
| OFF (default) | silent (bash on Unix, PowerShell on Windows) | BM lines live; full child log on failure |
| ON | unfiltered | Compiler / linker output as it happens |

---

## Fail-fast

`BUILDMASTER_FAIL_FAST=ON` writes a marker after a stage failure so
later stages skip instead of cascading. A nested BM `FATAL` already
fails that child CMake.

---

## Compiler cache

ccache / sccache launchers and cache directories propagate into
nested CMake and Meson (including the Meson native file). Keep the
native file aligned with `TOOLCHAIN=` so cache keys do not mix
compilers.

---

## Platform notes

- **Windows shared:** DLLs under `CMAKE_INSTALL_BINDIR`, import libs
  under `CMAKE_INSTALL_LIBDIR`. `RENAME` treats both and keeps the
  produced case.
- **Windows static:** archives under `LIBDIR` only.
- **Unix:** `lib` / `lib64` from `GNUInstallDirs` (BuildMaster loads
  it).
- Nested configure injects `-I`/`-L` (and Windows `INCLUDE`/`LIB`)
  for the shared prefix.

---

## Git helpers

Bound to a **component id**. Configure-time ops run when you call
them; a post-install reset can restore the tree after patching.

```cmake
buildmaster_git_reset(mylib "MyLib reset" ${MYLIB_SRC_DIR})
buildmaster_git_patch(mylib "MyLib patch" ${MYLIB_SRC_DIR} ${PATCH_FILE})
buildmaster_git_switch(mylib "MyLib branch" ${MYLIB_SRC_DIR} my-topic)
buildmaster_git_fetch(mylib "MyLib fetch" ${MYLIB_SRC_DIR})
```

Call these **before** `buildmaster_component` for that id. Patch is
queued; flush is reset-then-apply once per root.

---

## File download and decompress

CMake can already hash a download. What it does not give you for free
is a **stable cache** that survives `rm -rf build`, plus a call that
leaves the file on disk **before** `buildmaster_component` runs.

Default destination is `${BUILDMASTER_BINDIR}/downloads`. Point
`BUILDMASTER_DOWNLOADSDIR` at a folder *outside* the build tree.

```bash
export BUILDMASTER_DOWNLOADSDIR="$HOME/.cache/buildmaster/downloads"
```

| Function | Role |
|----------|------|
| `buildmaster_download_cached` | Reuse the file when the hash matches |
| `buildmaster_download` | Always fetch (progressive backoff) |
| `buildmaster_decompress` | Unpack into a directory |

These run at the call site. Then
`buildmaster_prerequisite(<id> <name>)` if a later rebuild of that
file target must precede configure.

---

## API map

| Area | Commands |
|------|----------|
| Components | `buildmaster_component` |
| Graph | `buildmaster_depend`, `buildmaster_link`, `buildmaster_prerequisite` |
| Hooks | `buildmaster_hook_component`, `buildmaster_hook_graph` |
| Meta | `buildmaster_meta`, `buildmaster_meta_add` |
| Repack | `buildmaster_repack` |
| Files | `buildmaster_download`, `buildmaster_download_cached`, `buildmaster_decompress` |
| Git | `buildmaster_git_fetch`, `buildmaster_git_switch`, `buildmaster_git_reset`, `buildmaster_git_patch` |
| Log | `buildmaster_message` |

Eighteen commands. `_bm_*` is internal. Stage generators, parse
helpers, import hints, `ensure_build_dir`, checksum and git marker
are not part of the supported surface.

Coming from 1.0.1: [`MIGRATE.md`](MIGRATE.md).

---

## Self-tests

A synthetic harness lives under `.github/tests/` (not part of the DSL
runtime). It has no real third-party projects. CI runs it on Linux,
Windows and macOS.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Supporting the project

If BuildMaster saved you from a third `POST_BUILD` rename script, a
star on the repo is the polite nod. A well-aimed issue is better than
a vague “it broke”. Pull requests that keep the DSL small are the
ones that land.

This is not a tip jar at the church door. It is a toolkit written
because the alternative was another private graph in every product.
Use it. Break it on purpose. Tell us which sentence in this file lied.
