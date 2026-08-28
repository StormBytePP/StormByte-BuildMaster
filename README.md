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

A dozen upstreams — some CMake, some Meson, one that installs `zsd.lib`
when you asked for `z.lib`, one that cannot configure until another prefix
exists, one that only behaves under `clang-cl`, and a static archive the
linker will drop unless you wrap it in `--whole-archive` — and you already
have a private orchestration layer. Usually it is `add_custom_command`,
hardcoded paths, and “remember to declare zlib before the image decoder”.

You have lived that week. The next `rm -rf build` should not start it again.

BuildMaster is that layer, written once:

| You stop writing… | You get… |
|-------------------|----------|
| “Declare A before B or configure explodes” | Order-independent registration |
| `ExternalProject` that configures at *build* time | Eager configure when the graph allows it |
| Hand-rolled Meson `setup` that misses `.pc` files | Same prefix, `PKG_CONFIG_PATH`, compilers, cache launchers |
| `POST_BUILD` rename scripts per MSVC flavor | `RENAME` on the component (default **ON**) |
| `--whole-archive` soup in the parent | `WHOLE` on a component or a **meta** collection |
| `LNK2005` / duplicate `.res` after `/WHOLEARCHIVE` | `STRIPRES` on static MSVC/clang-cl archives (default **ON**) |
| Hand-written `.pc` so the next Meson node finds this prefix | Optional helper `PC={…}` on the component |
| “Did anyone actually link this plugin?” | Orphan warnings at configure |
| Waiting on a slow tarball every `rm -rf build` | Point `BUILDMASTER_DOWNLOADSDIR` at a folder you keep |

The cost is a short public API. The payoff is a parent tree that looks like
a product, not a build blog.

---

## Table of contents

- [Layout (supported, not optional)](#layout-supported-not-optional)
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

## Layout (supported, not optional)

BuildMaster assumes **one bootstrap** and **one shared prefix**. That only
holds if every dependency you drive through the DSL sits **next to** the
BuildMaster checkout: same parent directory, sibling folders. Name that
parent whatever you want. The sibling rule is the supported contract.

```text
<parent>/
  CMakeLists.txt          # add_subdirectory of the siblings below
  buildmaster/            # this repository
  zlib/
  png/
  mycodec/
  …
```

```cmake
# <parent>/CMakeLists.txt
add_subdirectory(buildmaster)
include(buildmaster/helpers.cmake)

add_subdirectory(zlib)
add_subdirectory(png)
add_subdirectory(mycodec)
```

Each sibling `CMakeLists.txt` is the **registration** side (`create_*`,
`component_link`, …). The nested project that CMake or Meson actually
configures lives *inside* that sibling (`src/`, `lib/`, upstream’s own
tree). Do not point `srcdir` at the same listfile that called
`create_cmake_component`. That file consumes the DSL. The nested `-S`
must see a normal upstream project.

| This works | This is a different program |
|------------|-----------------------------|
| `buildmaster/` and `zlib/` as siblings | BuildMaster three levels down, `zlib/` somewhere else |
| Registration next to `src/` | `srcdir` = the file that called `create_*` |
| One `add_subdirectory(buildmaster)` per host | A second checkout “just for this folder” |
| Nested BM via the shared toolchain file | A second bootstrap that overwrites `toolchain.cmake` |

If you invent a prettier tree, you are outside the contract. The first
symptom is usually `File /configure.cmake.in does not exist` or a prefix
that only some nodes can see. That is not a CMake mystery. That is the
layout talking.

BuildMaster includes `GNUInstallDirs` itself so
`BUILDMASTER_INSTALL_LIBDIR` is not `install/` with a hole in the middle
because someone forgot a module.

---

## What it is

While the parent is still configuring, you **declare**:

- components (`create_cmake_component` / `create_meson_component` /
  headers variants / low-level `create_component`)
- collections (`create_meta_component` + `meta_component_add`)
- edges (`component_dependency`, `component_link`)
- optional work that must finish first (`component_prerequisite`, file
  and git helpers)

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

Sources can be a git checkout, a cached tarball, a submodule, or any tree
you already have on disk.

Typical shapes: a bundled third-party stack, several intermediate statics
that you later **repack**, a header-only SDK, a mixed CMake + Meson graph
on Linux / Windows / macOS, a plugin pack that a larger library links as
one `WHOLE` node.

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
| Strip `.res` from static MSVC archives | Manual `/REMOVE` | Manual | **Default ON static (`STRIPRES`)** |
| Helper `.pc` for the shared prefix | Manual | Manual | **Optional (`PC={…}`)** |
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
cmake_minimum_required(VERSION 3.20)
project(MyProduct LANGUAGES C CXX)

set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")  # optional

add_subdirectory(buildmaster)
include(buildmaster/helpers.cmake)

buildmaster_message(USER STATUS "Setting up zlib" 1)

# zlib/CMakeLists.txt — registration only, sibling of buildmaster/
ensure_build_dir(ZLIB_BUILDDIR)
create_cmake_component(
	zlib
	"zlib compression library"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	"${ZLIB_BUILDDIR}"
	"-DBUILD_SHARED_LIBS=OFF"
	static
	"z"
	"INDENT=1;PC={VERSION=1.3.1;NAME=zlib}"
)

add_executable(app app.c)
target_link_libraries(app PRIVATE zlib)
```

No out-variable. No generated fragment to `include()`. Stage targets and
IMPORTED libraries appear when the parent `CMakeLists.txt` finishes.

Optional policy string — one trailing argument, never another pile of
positionals:

```cmake
create_cmake_component(
	mylib
	"My Library"
	${MYLIB_SRC}
	${MYLIB_BUILD}
	"${MYLIB_OPTS}"
	static
	"mylib"
	"INDENT=2;TOOLCHAIN=clang-cl;RENAME;WHOLE;PC={VERSION=1.2.3;NAME=mylib}"
)
```

On a static MSVC / clang-cl archive, `STRIPRES` is already **ON**. You
only write it when you want it **OFF** (`STRIPRES=OFF`). Meson is the
same shape with `create_meson_component`.

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
5. End of `CMAKE_SOURCE_DIR`: BuildMaster materializes. Unused ids
   produce one **WARNING**.

| Nested configure | When |
|------------------|------|
| **Eager** | The component is not the `source` of any `component_dependency` — it configures while the parent configures. |
| **Deferred** | It depends on another node — configure runs at build time under `<id>_configure`. |

That is the same behaviour you want by hand (consumer after producer)
without writing two APIs. Deferred configure prints
`Setting up <title> for build-time configure` so a long wait is not a
silent hang.

`component_link` also records a dependency when the destination is a
BuildMaster node. Linking a `BUILDONLY` component is **FATAL**. A normal
component depending on `BUILDONLY` is **FATAL**.

Host executables use `target_link_libraries(app PRIVATE <id>)`. Non-BM
targets do not pretend to be DSL.

---

## How a component works

```text
create_*_component(
  <id> <title> <srcdir> <builddir> <options> <mode> <produced>
  [options_string]
)
```

| Target | Role |
|--------|------|
| `<id>` | `INTERFACE`. Depends on `<id>_install`. **This is what you link.** |
| `<id>_configure` | Nested CMake or Meson setup |
| `<id>_build` | Compile |
| `<id>_install` | Install into `BUILDMASTER_INSTALL_DIR` (skipped for `BUILDONLY`) |
| produced libs | `STATIC` / `SHARED` **IMPORTED** files under the prefix (or the build dir) |

| Argument | Role |
|----------|------|
| `id` | Registry key and INTERFACE target name (filesystem-friendly) |
| `title` | Human string in `STATUS` lines (spaces allowed) |
| `srcdir` | Upstream tree (its `CMakeLists.txt` / `meson.build`) |
| `builddir` | Out-of-source build; `ensure_build_dir()` if you omit the ritual |
| `options` | List forwarded as CMake `-D` or Meson `-D` |
| `mode` | `static`, `shared`, or the headers helpers |
| `produced` | Canonical names after `RENAME` (`z`, `vendor/foo`) |
| `options_string` | `KEY=value;FLAG;PC={…}` |

Library-mode installs list archive paths as `OUTPUT` so Ninja can depend
on real files, not empty stamps.

`create_component` is the same idea with an explicit backend
(`cmake` / `meson`). `create_*_stages` exist. They are **internal**.

---

## Dependencies and links

### `component_dependency(source, dest)`

Order-only edge. At materialize time `dest` resolves as the first match:

1. Registered component id → `<id>_install`
2. Registered **meta** id → `<id>_install`
3. Name matching `*_install` / `*_configure` / `*_build`
4. Existing CMake target (prerequisite, `file_*`, your own custom target)

Otherwise: **FATAL**.

Use this when you need *ordering* without a link line (headers-only
producer, a download that is not a library, a host target that writes
files).

### `component_link(source, dest)`

Records a link on the component `INTERFACE`.

If `dest` is a graph node (component, meta, stage, or existing target),
BuildMaster also records `component_dependency`. A raw library spec
(`foo`, `vendor/foo`) does **not** get an automatic wait edge.

Host binaries are not graph nodes. Link them the ordinary way:

```cmake
component_dependency(png zlib)
component_link(png zlib)
target_link_libraries(MyApp PRIVATE png)
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

`RENAME`, `BUILDONLY` and `STRIPRES` on a meta are ignored with a
**WARNING** when the key is actually written (there is nothing to install
or strip). The default-**ON** `STRIPRES` does not warn on a meta that
never mentioned it.

`PC={…}` on a meta is **FATAL**. A collection has no single library
contract. Generating one `.pc` from an unbounded member set would invent
`Requires` you did not choose and collide with upstream files. Put
`PC={…}` on the leaf that owns the archive.

### Membership is not consumption

| Call | Meaning |
|------|---------|
| `meta_component_add(meta, member…)` | *Membership.* `member` belongs to `meta`. |
| `component_link` / `component_dependency` / host `target_link_libraries` **to the meta** | *Consumption.* Something actually needs the collection. |

If nothing consumes the meta, members are **not** built just because they
were added. That is deliberate: a plugin pack you forgot to link should
not silently compile half the tree.

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

After materialize, components and metas that were never consumed — no
link, no dependency, no host `target_link_libraries`, no **used**
`component_repack` — are listed in a single **WARNING**.

Membership in an *unused* meta does not count. A `BUILDONLY` phase that
only feeds an unused repack is still an orphan (and so is that repack).

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
KEY=value;KEY2=value with spaces;PC={VERSION=1.0.0;NAME=foo}
```

| Rule | Detail |
|------|--------|
| Pair separator | `;` outside `{…}` |
| Brace group | `PC={…}` — `;` inside the braces is part of the group |
| Key / value | Only the **first** `=` in a pair |
| Keys | Case-insensitive, stored **UPPERCASE** |
| Values | May contain spaces and extra `=` (`test==value` is fine) |
| `;` outside braces | Pair break. `;` inside `{…}` is allowed |
| Bare flag | `RENAME` / `WHOLE` / `BUILDONLY` / `STRIPRES` / `PC` ≡ `KEY=ON` |
| Bare `PC` / `PC=ON` without `{…}` | **FATAL** — use `PC={VERSION=…}` or `PC={ENABLED=OFF}` |
| Unknown key | **WARNING**, ignored |
| Extra positional arguments | **FATAL** |

| Key | Default | Meaning |
|-----|---------|---------|
| `INDENT` / `INDENT_LEVEL` | `0` | Tabs after the log header (non-negative integer) |
| `TOOLCHAIN` | inherit | Profile (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `RENAME` | **ON** | Normalize archives to the declared name (install prefix, or build dir if `BUILDONLY`) |
| `WHOLE` | **OFF** | Whole-archive link of produced **static** archives |
| `BUILDONLY` | **OFF** | Do not install into the shared prefix |
| `STRIPRES` | **ON** | After `RENAME`, strip `.res` members from **static** MSVC / clang-cl archives |
| `PC={…}` | **OFF** | After install, write a **helper** `.pc` under the shared prefix |

---

## Whole-archive linking (`WHOLE`)

Static plugin-style archives often contain objects the linker will drop
unless the whole archive is forced in. Set `WHOLE` on the component or on
the meta that collects them.

One linear group per consumer (never nested `--whole-archive` sandwiches):

```text
-Wl,--whole-archive  A  B  -Wl,--no-whole-archive     # ELF
-Wl,-force_load,A  -Wl,-force_load,B                  # Mach-O
-WHOLEARCHIVE:A.lib  -WHOLEARCHIVE:B.lib              # MSVC (Ninja-safe spelling)
```

On shared, headers, or `BUILDONLY`, `WHOLE` is **ignored with a WARNING**.
A non-`WHOLE` library linked next to a `WHOLE` meta stays outside the
group.

`WHOLE` is why `STRIPRES` exists. Forcing every object out of two static
`.lib` files also forces every `.res` those archives still carry. Two
upstreams that both compiled a resource script suddenly share a symbol
name the linker will not forgive.

---

## Stripping `.res` members (`STRIPRES`)

A `.res` is a Windows resource object. In a DLL it is useful. In a
**static** `.lib` it is ballast: version info, manifests, icons nobody
will load from an archive member. MSVC and clang-cl still stuff one into
the library because that is what the toolchain does when a `.rc` is in
the sources.

Then you ask the linker for the whole archive — because otherwise the
plugin objects vanish — and two otherwise unrelated `.lib` files both
contribute `something.res`. The link dies with a duplicate resource
symbol. The “fix” people reach for is a one-off `lib /REMOVE:….res`
after staring at `lib /LIST` until they guess the member name. Next
upstream, next filename, next `POST_BUILD`.

BuildMaster does not ask you for the member name. After `RENAME` (so the
canonical `.lib` already exists), install lists every member with
`lib.exe` / `llvm-lib` `/LIST`, keeps only basenames that end in `.res`
(case-insensitive), and `/REMOVE`s those. Anything else in the archive
is left alone.

| Case | Behaviour |
|------|-----------|
| Static + MSVC / clang-cl + `STRIPRES` **ON** (default) | Strip after rename / contract |
| Static + `BUILDONLY` | Same, against the component build dir |
| Static + other toolchain | Silent no-op (no warning) |
| Shared / headers | **WARNING**, ignored |
| Meta | **WARNING** only if you wrote the `STRIPRES` key |
| `STRIPRES=OFF` | Skip. Use this if you actually need the resources |

If a repack consumes those statics, the inputs are already clean because
strip ran on each component’s install (or `BUILDONLY` “install”) first.

```cmake
create_cmake_component(
	plugin-a
	"Plugin A"
	${A_SRC} ${A_BUILD}
	"${A_OPTS}"
	static
	"plugina"
	"WHOLE"
)

create_cmake_component(
	branded
	"Branded static"
	${B_SRC} ${B_BUILD}
	"${B_OPTS}"
	static
	"branded"
	"STRIPRES=OFF"
)
```

---

## Helper pkg-config files (`PC`)

This is **not** a replacement for a real upstream `.pc`. It exists so
**later components in the same BuildMaster prefix** can find this library
without you writing a `file(WRITE …)` after install.

Typical pain: zlib lands under `BUILDMASTER_INSTALL_DIR` as `z.lib` (or
`zd.lib`, or `zsd.lib` — that is what `RENAME` is for). PNG will not
configure until that prefix exists. Meson looks at `PKG_CONFIG_PATH` and
finds nothing, because the project never shipped a `.pc` for *this*
layout. You already know the name, the version you care about, and the
`component_link` graph. BuildMaster can emit a small helper file from
that.

```cmake
create_cmake_component(
	zlib
	"zlib"
	${ZLIB_SRC} ${ZLIB_BUILD}
	"${ZLIB_OPTS}"
	static
	"z"
	"PC={VERSION=1.3.1;NAME=zlib}"
)

create_cmake_component(
	png
	"libpng"
	${PNG_SRC} ${PNG_BUILD}
	"${PNG_OPTS}"
	static
	"png"
	"PC={VERSION=1.6.43;NAME=libpng}"
)
component_link(png zlib)
```

After `zlib_install` / `png_install`:

```text
${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/zlib.pc
${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/libpng.pc   # Requires: zlib
```

`prefix` / `libdir` / `includedir` are the **BuildMaster install tree**.
That is enough for this project. A portable distro `.pc` is out of scope.

| Inner key | Required | Default |
|-----------|:--------:|---------|
| `VERSION` | when enabled | — **FATAL** if missing |
| `NAME` | no | First produced spec basename, else the component id |
| `DESCRIPTION` | no | Component title |
| `ENABLED` | no | **ON**. `ENABLED=OFF` skips the file and does not require `VERSION` |

| Field written | Source |
|---------------|--------|
| `Name` / `Version` / `Description` | Inner keys (or defaults above) |
| `Libs` | `-L${libdir}` plus `-l<produced>` for each produced spec |
| `Requires` | Direct `component_link` destinations that are registered components **with PC enabled** (not metas). One hop, not a full flatten |
| `Cflags` | Extra flags from the component’s own configure options minus the parent `CMAKE_C{,XX}_FLAGS`. Include tokens (`-I`, `/I`, `-isystem`) are dropped — the prefix include dir is already in the BM environment |

| Case | Behaviour |
|------|-----------|
| `PC={VERSION=…}` | Write after `RENAME` + `STRIPRES` |
| `PC={ENABLED=OFF}` | No file. Keep the group in the options string |
| Bare `PC` / `PC=ON` | **FATAL** — braces are the contract |
| File already exists at the canonical path | **FATAL** — do not clobber an upstream `.pc` |
| `BUILDONLY` + enabled `PC` | **FATAL** — there is no shared prefix to publish into |
| Meta + `PC={…}` | **FATAL** — unbounded membership, no single library |
| Unknown inner key | **WARNING**, ignored |

Keep `ENABLED=OFF` when you are mid-port and do not want to delete the
group. Turn it back on without rewriting the rest of the options string.

---

## Build-only components and repack

Some upstreams are not “the library you ship”. They are intermediate
static archives you later merge (several related builds, a main lib plus
an extra helper from the same tree).

`BUILDONLY`:

- still has `_configure` / `_build` / `_install` anchors (`_install` is a
  coherence target — it does not publish to the shared prefix)
- artifacts live in **that component’s build directory**
- `RENAME` is allowed and runs against the build dir
- `STRIPRES` is allowed and runs against the same build-dir archives
- `PC={…}` with `ENABLED=ON` is **FATAL** (helper `.pc` files belong on
  the shared prefix)
- `component_link` *from a normal component to a `BUILDONLY`* is
  **FATAL** (you cannot link a tree that was never installed)

`component_repack(id title output inputs…)` merges listed archives with
the host archiver (`ar` / `llvm-ar` / `lib.exe` / `libtool`) into one
file under the shared prefix and exposes it as an IMPORTED target.
Inputs may be `BUILDONLY` components. The repack waits on each input’s
**`_build`**, not `_install`, so `BUILDONLY` works. A custom host target
that only has artifacts (no `_build`) is accepted as a corner case.

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
compile. `WHOLE`, `STRIPRES` and `RENAME` do not apply; writing them is a
**WARNING**.

---

## Per-component toolchains

`TOOLCHAIN=` pins **that component** (and nested BuildMaster under it).
The parent job’s compiler does not change.

| Name | Typical drivers |
|------|-----------------|
| `gcc` | GNU `gcc` / `g++` |
| `clang` | Clang / AppleClang family |
| `clang-cl` | Clang in MSVC-compatible mode (Windows) |
| `msvc` | MSVC `cl` |

Children inherit unless they set their own. A meta `TOOLCHAIN` is copied
onto members that did not pin one. An explicit child value wins; two
different explicit values on the same node are **FATAL**.

Meson always receives the matching native file. That is what keeps
ccache / sccache honest when the compiler changes down the tree.

On Apple, `AppleClang` is the clang family. A “swap to gcc” means a real
GNU `gcc`, not `/usr/bin/gcc` that is still Clang wearing a name tag.

---

## Recursive usage

A sibling may `add_subdirectory(buildmaster)` again. The shared
`BUILDMASTER_TOOLCHAIN_FILE` is the source of truth. A second full
bootstrap is refused so it cannot write an incomplete toolchain file
over the parent’s. The prefix stays the parent’s prefix. APIs remain
available.

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
lines such as “Setting up the library”, not an internal name like
`CMake`.

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
| `INFO` | Optional progress (rename skip, unpack OK, `.res` strip skip) |
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
- Any other level: `[<LEVEL>][BuildMaster/<Module>]: <tabs><text>` (no
  space between the two brackets)
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
| `ARCHIVE` | Archive | Static merge / archiver / `.res` strip |
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

`BUILDMASTER_LOGLEVEL` only filters **BuildMaster lines**. Live compiler
/ linker stdout is a separate switch:

```bash
export BUILDMASTER_VERBOSE=1
```

| Stage | Effect |
|-------|--------|
| `cmake --build` | Live compile runner + `--verbose` |
| `meson compile` | Live compile runner + `-v` |
| Configure / setup / install / git | Unchanged unless you raise `LOGLEVEL` |

`LOGLEVEL` does **not** imply `VERBOSE`. Silent runners still hide tool
stdout on success and dump it on failure (Unix shell and Windows
PowerShell).

| LOGLEVEL | VERBOSE | BuildMaster lines | Compile lines |
|----------|---------|-------------------|---------------|
| `STATUS` | **OFF** | Stage titles | Quiet |
| `DEBUG` | **OFF** | Graph + git + paths | Quiet |
| `STATUS` | **ON** | Stage titles | Live + `--verbose` / `-v` |
| `LOWLEVEL` | **ON** | Everything | Live + `--verbose` / `-v` |

---

## Fail-fast

A non-zero nested build/install fails that stage. The INTERFACE target
depends on `<id>_install`, so the parent does not compile against a
half-empty prefix.

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
| `.res` strip | no-op | `lib` / `llvm-lib` `/LIST` + `/REMOVE` | no-op |
| Meson PDB | — | `/Z7` | — |
| `TOOLCHAIN=clang` | LLD required | use `clang-cl` | LLD not forced |
| `TOOLCHAIN=msvc` / `clang-cl` | invalid | supported | invalid |

AppleClang is treated as the **clang** family for toolchain swap tests
and profile selection. Minimum CMake **3.20**
(`cmake_language(DEFER)`). A host `cmake_minimum_required` that is older
should fail before the DSL pretends to work.

---

## Git helpers

Bound to a **component id**. Configure-time ops run when you call them; a
post-install reset can restore the tree after patching.

```cmake
create_git_reset_file(mylib "MyLib reset" ${MYLIB_SRC_DIR})
create_git_patch_file(mylib "MyLib patch" ${MYLIB_SRC_DIR} ${PATCH_FILE})
create_git_switch_branch(mylib "MyLib branch" ${MYLIB_SRC_DIR} my-topic)
create_git_fetch(mylib "MyLib fetch" ${MYLIB_SRC_DIR})
```

`buildmaster_clean` resets registered git roots and is meant to be
followed by a reconfigure.
`buildmaster_git_post_install_marker_for_srcdir` resolves the reset
script path for a source tree.

---

## File download and decompress

CMake can already hash a download. What it does not give you for free is
a **stable cache** that survives `rm -rf build`.

Default destination is `${BUILDMASTER_BINDIR}/downloads`. Point
`BUILDMASTER_DOWNLOADSDIR` at a folder *outside* the build tree and the
same URL + hash is reused on the next configure. No extra `if(EXISTS)`,
no hand-rolled stamp files.

```bash
export BUILDMASTER_DOWNLOADSDIR="$HOME/.cache/buildmaster/downloads"
# or
cmake -DBUILDMASTER_DOWNLOADSDIR=/var/cache/buildmaster/downloads …
```

```cmake
file_download_cached(my-data
	"https://example.invalid/extra.tar.gz"
	EXPECTED_HASH SHA256=${EXTRA_HASH}
	TITLE "Example extra data"
)
include(${my-data})

file_decompress(my-unpack
	"${BUILDMASTER_DOWNLOADSDIR}/extra.tar.gz"
	"${CMAKE_BINARY_DIR}/extra"
	TITLE "Example extra data"
)
include(${my-unpack})

component_prerequisite(mylib my-unpack)
```

A slow extra-data tarball from a far-away host should not be the reason
you wait before you can compile *your* code again. The first run pays
the network. Every run after that is a hash check against a file you
already have.

---

## API map

| Area | Commands |
|------|----------|
| Components | `create_cmake_component`, `create_meson_component`, `create_cmake_headers_component`, `create_meson_headers_component`, `create_component` |
| Graph | `component_dependency`, `component_link`, `component_prerequisite` |
| Meta | `create_meta_component`, `meta_component_add` |
| Repack | `component_repack` |
| Files | `file_download`, `file_download_cached`, `file_decompress`, `file_checksum_correct` |
| Git | `create_git_reset_file`, `create_git_patch_file`, `create_git_switch_branch`, `create_git_fetch` |
| Log | `buildmaster_message` |
| Paths / import | `ensure_build_dir`, `library_import_hint`, `library_import_static_hint`, `sanitize_for_filename`, `buildmaster_parse_subcomponent` |
| Toolchain | `buildmaster_validate_toolchain`, `buildmaster_load_toolchain_profile`, `buildmaster_find_archiver` |
| Options | `buildmaster_parse_component_options`, `buildmaster_parse_component_pc` |
| Git extras | `buildmaster_clean`, `buildmaster_git_post_install_marker_for_srcdir` |

Stage generators (`create_cmake_stages` / `create_meson_stages`) are
**internal**.

---

## Self-tests

A synthetic harness and a host-style consumer live under
`.github/tests/` (not part of the DSL runtime). The consumer copies the
supported sibling layout: BuildMaster and the nested library sit next to
each other.

```bash
cmake -S .github/tests/harness -B build/harness -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/harness --target run_buildmaster_checks
cmake --build build/harness --target run_buildmaster_smoke

cmake -S .github/tests/consumer -B build/tests/consumer -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/tests/consumer --target consumer_host
```

Extend the harness by editing `.github/tests/expected/`. Do not hardcode
new assertions in `.github/workflows/ci.yml`.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Supporting the project

The license does not require anything of you. If BuildMaster deleted a
week of `POST_BUILD` scripts from your tree and you would like the next
week deleted too, a PayPal note to **StormByte@gmail.com** helps keep
this module — and the rest of the StormByte suite — in fighting shape.
Other channels: open an issue and say you would rather not use PayPal.

Thank you for reading this far. That usually means the graph hurt.
