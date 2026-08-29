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
| `LNK2005` / duplicate `.res` after `/WHOLEARCHIVE` | `STRIPRES` on static MSVC/clang-cl archives (default on) |
| `shlwapi` on every consumer because a static `.lib` does not record it | Optional `LINK={…}` on the producer (or the meta) |
| Hand-written `.pc` so the next Meson node finds this prefix | Optional helper `PC={…}` on the component |
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
| Download / unpack during parent configure | Manual | No | **Yes** (`file_*` helpers) |
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
| Strip `.res` from static MSVC archives | Manual `/REMOVE` | Manual | **Default on static (`STRIPRES`)** |
| Raw system libs on the INTERFACE | Manual on every consumer | Manual | **Optional (`LINK={…}`)** |
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
    "INDENT=2;TOOLCHAIN=clang-cl;RENAME;WHOLE;LINK={shlwapi;ws2_32};PC={VERSION=1.2.3;NAME=mylib}"
)
```

On a static MSVC / clang-cl archive, `STRIPRES` is already on. You only
write it when you want it off (`STRIPRES=OFF`). Meson is the same shape
with `create_meson_component`.

---

## Declarative model

1. **Register** components (order does not matter).
2. **Optional:** group them with `create_meta_component` /
   `meta_component_add` (`add` may run *before* `create`).
3. **Connect** with `component_dependency` and/or `component_link`
   (again, any order).
4. **Optional:** `component_prerequisite`, `file_download` /
   `file_download_cached` / `file_decompress` (these run during the
   call, so sources exist before `create_*`), or configure-time
   `create_git_*`.
5. End of `CMAKE_SOURCE_DIR`: BuildMaster materializes. Unused ids produce
   one **WARNING**.

| Nested configure | When |
|------------------|------|
| **Eager** | The component is not the `source` of any `component_dependency` — it can configure while the parent configures. |
| **Deferred** | It depends on another node — configure runs at build time under `<id>_configure`. |

That is the same behaviour you want by hand (consumer after producer)
without writing two APIs.

A tarball you unpack in the same `CMakeLists.txt` as `create_*` does
**not** need a dependency edge for the first configure: the files are
already on disk. Add `component_dependency` / `component_prerequisite`
only when a *later rebuild* of that file target must precede configure.

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

The `INTERFACE` stub exists as soon as you call `create_*`. You may
`add_library(Vendor::Foo ALIAS foo)` in the same file. Produced paths
are filled in at materialize.

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

`dest` is a **BuildMaster graph node**: another component, a meta, an
existing CMake target, an archive that already exists on disk, or a
library spec (`<name>` / `<subdir>/<name>`) under the BM prefix. If it
is a graph node, BuildMaster also records `component_dependency`.

It is **not** where you list `shlwapi`. A dest that matches none of the
kinds above is **FATAL** — that name belongs in `LINK=` on the producer
(see the next section).

Host binaries are not graph nodes. Link them the ordinary way:

```cmake
target_link_libraries(MyApp PRIVATE mylib)
target_link_libraries(MyApp PRIVATE plugins)  # a meta
```

---

## Raw system libraries (`LINK`)

A static `mariadbclient.lib` does not “contain” `shlwapi`. The `.obj`
files inside it have `__declspec(dllimport) PathRemoveFileSpecA`, and
the linker of **your** DLL is the one that has to see `shlwapi.lib`.
Repeating that on every consumer is how the line rots.

`LINK` is the declaration on the **producer** (or on a meta that groups
producers): whoever links this `INTERFACE` also links these names.

```cmake
create_cmake_component(
    MariaDB-ConnectorC
    "MariaDB Connector C"
    ${MARIADB_C_SRCDIR}
    ${MARIADB_C_BUILDDIR}
    "${MARIADB_C_OPTIONS}"
    static
    "mariadbclient"
    "INDENT=1;LINK={shlwapi;ws2_32;advapi32}"
)

target_link_libraries(StormByte-Database PRIVATE MariaDB-ConnectorC)
```

CMake then carries `shlwapi` through the chain to `StormByte-Database.dll`.
You did not repair Connector-C’s own CMake. You told the BM target the
truth about what a consumer of that target must pass to the linker.

| Form | Meaning |
|------|---------|
| omitted | nothing extra |
| `LINK=shlwapi` | one raw linker name |
| `LINK={shlwapi;ws2_32}` | several — `;` inside `{…}` is not a pair break |
| `LINK=` / bare `LINK` | **FATAL** |
| several items without braces | **FATAL** |

Items are **external to BuildMaster**. They go to the linker as written
(`shlwapi`, `ws2_32`). They are not component ids, not metas, not CMake
targets, and not specs under the install prefix. A name that collides
with an existing `TARGET` may be resolved by CMake as that target — do
not pick colliding names.

This does **not** fix a program that links the third-party archive
without going through the BM `INTERFACE`. If someone runs
`lld-link … mariadbclient.lib` by hand, `LINK` does not exist. That is
the point of the contract, not a bug.

Headers mode has no link line: `LINK` is **INFO**, ignored.
A meta **accepts** `LINK` and puts the names on the collection
`INTERFACE`, so you declare the syslibs once instead of on every member.

`LINK_EXTRA` from 1.x is gone. Same idea, shorter name, no graph
confusion. Using the old key is a **WARNING**.

---

## Meta components

A **meta** is an `INTERFACE` plus a graph anchor. No sources, no compile,
no artifacts of its own. It collects members (components, other metas,
static or shared) and forwards wait + link. It may set `WHOLE` on the
collection even if members did not. It may set `LINK` on the collection
even if members did not.

`TOOLCHAIN` on a meta does **not** compile the meta. At materialize time
that profile is copied onto members (and onto `component_dependency` /
`component_link` destinations whose source is the meta) that do not
already have `TOOLCHAIN` set. An explicit `TOOLCHAIN` on the child is
kept. Two metas inheriting **different** profiles onto the same empty
destination is **FATAL**.

`RENAME`, `BUILDONLY` and `STRIPRES` on a meta are ignored with **INFO**
when the key is actually written (there is nothing to install or strip).
The default-on `STRIPRES` does not log on a meta that never mentioned it.

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
were added. That is deliberate: a plugin pack you forgot to link should not
silently compile half the tree.

`meta_component_add` may run before `create_meta_component`. Cycles
(`plugins → codecs → plugins`) are **FATAL**.

```cmake
meta_component_add(plugins zlib png)
create_meta_component(plugins "Plugin pack" "INDENT=1;WHOLE;TOOLCHAIN=clang;LINK={m}")
component_link(engine plugins)
target_link_libraries(MyApp PRIVATE engine)
```

`zlib` and `png` compile as `clang` unless they already declared their
own `TOOLCHAIN`. `LINK={m}` rides on `plugins` and therefore on `engine`
and `MyApp`.

---

## Orphan warnings

After materialize, components and metas that were never consumed — no link,
no dependency, no host `target_link_libraries`, no **used** `component_repack`
— are listed in a single **WARNING**. That line is visible at the default
log level (`STATUS`). Membership in an *unused* meta does not count. A
`BUILDONLY` phase that only feeds an unused repack is still an orphan
(and so is that repack).

---

## Prerequisites

```cmake
component_prerequisite(mylib my-unpack)
```

`<id>_configure` waits on an existing target: a download, an unpack, a
custom codegen step, anything CMake already knows.

File helpers already run during the `file_*` call (see below). Use a
prerequisite or `component_dependency` when a **rebuild** of that target
must happen before a *deferred* configure — not to get the files onto
disk the first time.

---

## Component options

Every `create_*_component` accepts **at most one** optional trailing
argument:

```text
KEY=value;KEY2=value with spaces;LINK={shlwapi;ws2_32};PC={VERSION=1.0.0;NAME=foo}
```

| Rule | Detail |
|------|--------|
| Pair separator | `;` outside `{…}` |
| Brace group | `PC={…}` and `LINK={…}` — `;` inside the braces is part of the group |
| Key / value | Only the **first** `=` in a pair |
| Keys | Case-insensitive, stored **UPPERCASE** |
| Values | May contain spaces and extra `=` (`test==value` is fine) |
| `;` outside braces | Pair break. `;` inside `{…}` is allowed |
| Bare flag | `RENAME` / `WHOLE` / `BUILDONLY` / `STRIPRES` / `PC` ≡ `KEY=ON` |
| Bare `PC` / `PC=ON` without `{…}` | **FATAL** — use `PC={VERSION=…}` or `PC={ENABLED=FALSE}` |
| Bare `LINK` / `LINK=` | **FATAL** — use `LINK=name` or `LINK={a;b}` |
| Unknown key | **WARNING**, ignored |
| Extra positional arguments | **FATAL_ERROR** |

| Key | Meaning |
|-----|---------|
| `INDENT` / `INDENT_LEVEL` | Tabs after the log header (non-negative integer) |
| `TOOLCHAIN` | Profile (`gcc`, `clang`, `clang-cl`, `msvc`). Empty = inherit |
| `RENAME` | Normalize archives to the declared name (install prefix, or build dir if `BUILDONLY`) |
| `WHOLE` | Whole-archive link of produced **static** archives |
| `BUILDONLY` | Do not install into the shared prefix |
| `STRIPRES` | After `RENAME`, strip `.res` members from **static** MSVC / clang-cl archives (default **ON**) |
| `LINK=` / `LINK={…}` | Raw system linker names on the component or meta `INTERFACE` |
| `PC={…}` | After install, write a **helper** `.pc` under the shared prefix (see below) |

`LINK_EXTRA` is not a key. It **WARNING**s and is ignored.

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

On shared, headers, or a meta with no static members, `WHOLE` is **ignored
with INFO**. A non-WHOLE library linked next to a WHOLE meta stays outside
the group.

`WHOLE` is why `STRIPRES` exists. Forcing every object out of two static
`.lib` files also forces every `.res` those archives still carry. Two
upstreams that both compiled a resource script suddenly share a symbol
name the linker will not forgive. See the next section.

---

## Stripping `.res` members (`STRIPRES`)

You already know this one if you have ever linked a **static** plugin pack
on MSVC with `/WHOLEARCHIVE`.

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
| Static + MSVC / clang-cl + `STRIPRES` on (default) | Strip after rename / contract |
| Static + `BUILDONLY` | Same, against the component build dir |
| Static + other toolchain | Silent no-op (no warning) |
| Shared / headers | **INFO** only if you wrote the `STRIPRES` key (default is ON) |
| Meta | **INFO** only if you wrote the `STRIPRES` key |
| `STRIPRES=OFF` | Skip. Use this if you actually need the resources |

You do not list members. You do not write a per-library script. If a
repack consumes those statics, the inputs are already clean because
strip ran on each component’s install (or BUILDONLY “install”) first.

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

# Opt out when the .res is load-bearing:
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

Typical pain: the archive lands under `BUILDMASTER_INSTALL_DIR`, Meson
or another CMake node looks at `PKG_CONFIG_PATH`, and the project never
shipped a `.pc` (or shipped one only for the system layout). You already
know the name, the version you care about, and the `component_link` graph.
BuildMaster can emit a small helper file from that.

```cmake
create_cmake_component(
    ogg
    "Ogg"
    ${OGG_SRC} ${OGG_BUILD}
    "${OGG_OPTS}"
    static
    "ogg"
    "PC={VERSION=1.3.5;NAME=ogg;DESCRIPTION=Ogg bitstream}"
)

create_cmake_component(
    vorbis
    "Vorbis"
    ${VORBIS_SRC} ${VORBIS_BUILD}
    "${VORBIS_OPTS}"
    static
    "vorbis"
    "PC={VERSION=1.3.7;NAME=vorbis}"
)
component_link(vorbis ogg)
```

After `ogg_install` / `vorbis_install`:

```text
${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/ogg.pc
${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/vorbis.pc   # Requires: ogg
```

`prefix` / `libdir` / `includedir` are the **BuildMaster install tree**.
That is enough for this project. A portable distro `.pc` is out of scope.

| Inner key | Required | Default |
|-----------|:--------:|---------|
| `VERSION` | when enabled | — **FATAL** if missing |
| `NAME` | no | First produced spec basename, else the component id |
| `DESCRIPTION` | no | Component title |
| `ENABLED` | no | `TRUE`. `ENABLED=FALSE` skips the file and does not require `VERSION` |

| Field written | Source |
|---------------|--------|
| `Name` / `Version` / `Description` | Inner keys (or defaults above) |
| `Libs` | `-L${libdir}` plus `-l<produced>` for each produced spec |
| `Requires` | Direct `component_link` destinations that are registered components **with PC enabled** (not metas). One hop, not a full flatten |
| `Cflags` | Extra flags from the component’s own configure options minus the parent `CMAKE_C{,XX}_FLAGS`. Include tokens (`-I`, `/I`, `-isystem`) are dropped — the prefix include dir is already in the BM environment |

| Case | Behaviour |
|------|-----------|
| `PC={VERSION=…}` | Write after RENAME + STRIPRES |
| `PC={ENABLED=FALSE}` | No file. Keep the group in the options string |
| Bare `PC` / `PC=ON` | **FATAL** — braces are the contract |
| File already exists at the canonical path | **FATAL** — do not clobber an upstream `.pc` |
| `BUILDONLY` + enabled PC | **FATAL** — there is no shared prefix to publish into |
| Meta + `PC={…}` | **FATAL** — unbounded membership, no single library |
| Unknown inner key | **WARNING**, ignored |

Keep `ENABLED=FALSE` when you are mid-port and do not want to delete the
group. Turn it back on without rewriting the rest of the options string.

---

## Build-only components and repack

Some upstreams are not “the library you ship”. They are intermediate
static archives you later merge (several bit-depth builds, a main lib plus
a plugin pack). Mark them `BUILDONLY`: they compile into the component
build dir and never enter the shared prefix. `component_repack` then
publishes one archive from those inputs.

A `BUILDONLY` component is not a link dest (`component_link` to it is
**FATAL**). Wait on its stages with `component_dependency`, or consume it
only as a repack input.

---

## Subcomponent specs

Produced libraries are `<name>` or `<subdir>/<name>`. The install layout
keeps the subdirectory (`lib/recursive/cmake/midlib.a`). `component_link`
accepts the same spec form when the dest is not a registered id — the
archive need not exist at configure. Stage `OUTPUT` lists only the specs
declared on `create_*`; extra spec-link files get a Ninja wait-rule on
`<id>_install`. Unix Makefiles often hide the missing rule. Ninja does not.

---

## Header-only components

`create_cmake_headers_component` / `create_meson_headers_component` still
run configure / build / install for the include tree. There is no produced
archive and no link line. `LINK` on a headers component is **INFO**,
ignored.

---

## Per-component toolchains

| Profile | Compilers | Notes |
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

Third-party trees that themselves vendor BuildMaster must sit as **sibling
directories** of the BuildMaster checkout the parent added. Nested projects
expect that layout.

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
-- [BuildMaster/User     ]:	Setting up the library
-- [INFO    ][BuildMaster/User     ]:		extra data already cached
```

### Levels

Higher number = quieter filter threshold for the *optional* levels.
`WARNING` and `FATAL` ignore the threshold.

| Level | Role |
|-------|------|
| `LOWLEVEL` | Function enter/exit and path plumbing |
| `DEBUG` | Useful when debugging BuildMaster or a consumer graph |
| `INFO` | Policy that was ignored because it cannot apply (STRIPRES/WHOLE/LINK on the wrong mode, ignored keys on a meta, rename already done) |
| `WARNING` | Something you should fix: unknown option, `LINK_EXTRA`, orphan component. **Always printed.** |
| `STATUS` | Default narrative. Stage titles (`Configuring` / `Compiling` / `Installing`) |
| `FATAL` | Always printed. Stops configure/script. Never filtered |

Default `BUILDMASTER_LOGLEVEL` is `STATUS`. You see STATUS, WARNING and
FATAL. You do not see INFO / DEBUG / LOWLEVEL until you lower the filter.

`BUILDMASTER_LOGLEVEL=FATAL` still prints WARNING (and FATAL). Allowed;
discouraged if you wanted silence — there is no `SILENT` level.

An unknown level (typo `DEHBUG`) is **FATAL** and lists accepted names.

### Filter

| Level | When it prints |
|-------|----------------|
| `FATAL` | Always |
| `WARNING` | Always |
| `STATUS` / `INFO` / `DEBUG` / `LOWLEVEL` | When its number is **≥** current `BUILDMASTER_LOGLEVEL` |

Set `BUILDMASTER_LOGLEVEL=INFO` (cache or env) to see ignored-policy lines
and rename skips. `LOWLEVEL` is the firehose.

### Format

`STATUS` lines use only the module header. Other levels prefix a padded
level tag with **no space** between the two brackets:

```text
-- [BuildMaster/CMake    ]:	Configuring My Library
-- [WARNING ][BuildMaster/Component]:	orphan component(s) / meta(s): leftover
-- [INFO    ][BuildMaster/Rename   ]:	rename: already present (skip)
-- [DEBUG   ][BuildMaster/File     ]:	cache hit
```

`BUILDMASTER_DEBUG` is ignored. Use `BUILDMASTER_LOGLEVEL`.

---

## Verbosity of tool output

`BUILDMASTER_VERBOSE` is independent of the log level. It controls whether
nested CMake / Meson / Ninja stdout is shown on success. Failures always
print captured output.

---

## Fail-fast

`BUILDMASTER_FAIL_FAST=ON` writes a marker after a stage failure so later
stages skip instead of cascading.

---

## Compiler cache

ccache / sccache launchers and cache directories propagate into nested
CMake and Meson (including the Meson native file). Keep
`BUILDMASTER_MESON_NATIVE_FILE` aligned with `TOOLCHAIN=` so cache keys
do not mix compilers.

---

## Platform notes

- **Windows shared:** DLLs under `CMAKE_INSTALL_BINDIR`, import libs under
  `CMAKE_INSTALL_LIBDIR`. `RENAME` treats both and keeps the produced case.
- **Windows static:** archives under `LIBDIR` only.
- **Unix:** `lib` / `lib64` from `GNUInstallDirs` (BuildMaster loads it).
- Nested configure injects `-I`/`-L` (and Windows `INCLUDE`/`LIB`) for the
  shared prefix so a child project finds siblings without extra flags.

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
**stable cache** that survives `rm -rf build`, plus a call that leaves the
file on disk **before** `create_*_component` runs.

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
wait before you can compile *your* code again. The first configure pays the
network; every configure after that is a hash check against a file you
already have.

| Function | Role |
|----------|------|
| `file_download_cached` | Reuse the file when the hash matches; download only on miss or mismatch |
| `file_download` | Always fetch (progressive backoff) |
| `file_decompress` | Unpack into a directory |

**Contract**

- No out-variable. No `include()` of a generated script.
- Each call creates a CMake target of the same `name`.
- The generated `-P` script also runs **during that call** (parent
  configure). Scripts are idempotent: a cache hit or an already-extracted
  tree is a no-op.
- After `file_download_cached` / `file_decompress` return, the artifact is
  on disk. You may `create_*_component` against that tree in the same
  file; that component can still **eager**-configure.
- `DEPENDS` on the file helpers is a *build-graph* edge only. It does not
  delay the configure-time run. Call download before decompress in the
  same `CMakeLists.txt`.
- Paths are rejected if they contain `..` traversal.
- Optional graph wiring: `component_prerequisite` / `component_dependency`
  so a **rebuild** of the file target precedes a deferred `<id>_configure`.
  You do not need that edge just to unpack once at configure.

```cmake
file_download_cached(extra-download
    "https://example.invalid/extra.tar.gz"
    EXPECTED_HASH SHA256=${EXTRA_HASH}
    TITLE "Example extra data"
    INDENT 2
)

file_decompress(extra-unpack
    "${BUILDMASTER_DOWNLOADSDIR}/extra.tar.gz"
    "${CMAKE_BINARY_DIR}/extra"
    TITLE "Example extra data"
    INDENT 2
)

create_cmake_component(
    mylib
    "My Library"
    "${CMAKE_BINARY_DIR}/extra/upstream"
    "${CMAKE_BINARY_DIR}/extra_build"
    "${_opts}"
    static
    "mylib"
)
```

`BUILDMASTER_DOWNLOADSDIR` is the cache. The unpack destination is yours
(usually under the build tree). Keep the cache folder if you wipe `build/`.

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
| Options | `buildmaster_parse_component_options`, `buildmaster_parse_component_pc`, `buildmaster_parse_component_link` |

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
