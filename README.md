# StormByte BuildMaster

[![CI](https://github.com/StormBytePP/StormByte-BuildMaster/actions/workflows/ci.yml/badge.svg)](https://github.com/StormBytePP/StormByte-BuildMaster/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CMake ≥ 3.20](https://img.shields.io/badge/CMake-%E2%89%A5%203.20-064F8C)](https://cmake.org/)
[![CMake · Meson](https://img.shields.io/badge/backends-CMake%20%7C%20Meson-orange)](#how-a-component-works)
[![Linux · Windows · macOS](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)](#platform-notes)
[![Sponsor](https://img.shields.io/badge/Sponsor-StormBytePP-ea4aaa?logo=githubsponsors)](https://github.com/sponsors/StormBytePP)

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
hardcoded paths, and “remember to declare zlib before libpng”.

Those weeks do not make you a worse programmer. They make you the person
this file is for.

BuildMaster is that layer, written once:

| You stop writing… | You get… |
|-------------------|----------|
| “Declare A before B or configure explodes” | Order-independent registration |
| `ExternalProject` that only configures at *build* time | Eager configure when the graph allows it |
| A wait edge *and* a link edge for the same pair | `buildmaster_link` already waits |
| Hand-rolled Meson `setup` that misses `.pc` files | Same prefix, `PKG_CONFIG_PATH`, compilers, cache launchers |
| `POST_BUILD` rename scripts per MSVC flavor | `RENAME` (default on) |
| `--whole-archive` soup in the parent | `WHOLE` on a component or a **meta** |
| `LNK2005` / duplicate `.res` after `/WHOLEARCHIVE` | `STRIPRES` on static MSVC / clang-cl archives (default on) |
| `shlwapi` on every consumer because a static `.lib` does not record it | `LINK={…}` on the producer (or the meta) |
| `/FORCE:MULTIPLE` on the **parent** because one leaf needed it | `LINKFLAGS={…}` on **that** leaf (not inherited) |
| Hand-written `.pc` so the next Meson node finds this prefix | `PC={…}` on the leaf |
| `cmake_language(DEFER)` so a summary line appears *after* the graph | Hooks |
| Waiting on a slow tarball every `rm -rf build` | `BUILDMASTER_DOWNLOADSDIR` outside the build tree |
| Four public git helpers plus an `include()` | `GIT={…}` on the component |
| A download target plus a prerequisite edge | `FILES={…}` on the component |
| Manual `INDENT=` so related leaves line up in the log | `buildmaster_group` |

The cost is a short public API. The payoff is a parent tree that looks like
a product, not a build blog.

---

## Table of contents

- [Quick start](#quick-start)
- [Ten commands](#ten-commands)
- [How a component works](#how-a-component-works)
- [Dependencies and links](#dependencies-and-links)
- [Raw system libraries (`LINK`)](#raw-system-libraries-link)
- [Raw linker flags (`LINKFLAGS`)](#raw-linker-flags-linkflags)
- [Meta components](#meta-components)
- [Groups](#groups)
- [Component options](#component-options)
- [Build-only components and repack](#build-only-components-and-repack)
- [Header-only components](#header-only-components)
- [Files (`FILES`)](#files-files)
- [Git (`GIT`)](#git-git)
- [Helper pkg-config files (`PC`)](#helper-pkg-config-files-pc)
- [Whole-archive linking (`WHOLE`)](#whole-archive-linking-whole)
- [Stripping `.res` members (`STRIPRES`)](#stripping-res-members-stripres)
- [Subcomponent specs](#subcomponent-specs)
- [Per-component toolchains](#per-component-toolchains)
- [Hooks](#hooks)
- [Orphan warnings](#orphan-warnings)
- [Logging](#logging)
- [Verbosity of tool output](#verbosity-of-tool-output)
- [Fail-fast](#fail-fast)
- [Compiler cache](#compiler-cache)
- [Recursive usage](#recursive-usage)
- [Platform notes](#platform-notes)
- [Comparison](#comparison)
- [Self-tests](#self-tests)
- [License](#license)
- [Supporting the project](#supporting-the-project)

---

## Quick start

```cmake
add_subdirectory(path/to/buildmaster)

buildmaster_message(STATUS "Setting up My Library" 1)

buildmaster_component(
	mylib
	"My Library"
	"${CMAKE_SOURCE_DIR}/thirdparty/mylib/src"
	"-DENABLE_FOO=ON"
	shared
	mylib
)

target_link_libraries(MyApp PRIVATE mylib)
```

No build directory. No out-variable. No generated fragment to `include()`.
The backend is inferred from `srcdir` (`CMakeLists.txt` vs `meson.build`).
Stage targets and the `INTERFACE` stub named `mylib` exist when
registration returns; produced paths are filled in at the end of
`CMAKE_SOURCE_DIR`.

Optional policy string (one trailing argument):

```cmake
buildmaster_component(
	mylib
	"My Library"
	"${CMAKE_SOURCE_DIR}/thirdparty/mylib/src"
	"-DENABLE_FOO=ON"
	static
	mylib
	"INDENT=2;TOOLCHAIN=clang-cl;WHOLE;LINK={shlwapi;ws2_32};PC={VERSION=1.2.3;NAME=mylib}"
)
```

On a static MSVC / clang-cl archive, `STRIPRES` and `RENAME` are already
on. Write them only when you want them off.

`add_subdirectory` is enough. Do not `include(helpers.cmake)` from a
consumer.

---

## Ten commands

Ten commands. If you need an eleventh, the optstr is lying or the graph is.

| Command | Role |
|---------|------|
| `buildmaster_component(id title srcdir options mode produced [optstr])` | Factory. Backend from `srcdir`. No builddir |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest)` | Link on the component `INTERFACE` **and** a depend edge when `dest` is a graph node |
| `buildmaster_meta(id title [, optstr])` | `INTERFACE` collection. `REPACK` publishes one merged static archive |
| `buildmaster_meta_add(meta member…)` | Membership (allowed before `buildmaster_meta`) |
| `buildmaster_group(id [title])` | Outline banner. No target, no edge |
| `buildmaster_group_add(group member…)` | Membership (group / component / meta). Group must already exist |
| `buildmaster_hook_component(id fn alias [CAPTURE …])` | Run `fn` after that id materializes |
| `buildmaster_hook_graph(fn alias [CAPTURE …])` | Run `fn` after the whole graph materializes |
| `buildmaster_message(level text [, indent])` | Log. Module is always `USER` |

Everything else is `_bm_*` and is **not** a supported API.

**Ids** become target and script names — keep them filesystem-friendly.
**Titles** may contain spaces; they only appear in status lines.

Neutral entries in the `options` list (`CFLAGS`, `CXXFLAGS`, `CPPFLAGS`,
`LDFLAGS`, `INCLUDES`, `DEFINITIONS`) are **private** to the nested
compile and **append** to the parent job / toolchain.

---

## How a component works

While the parent is still configuring, you **declare**. You do **not**
`include()` generated fragments. You do **not** call a public finalize.
Materialization runs once via an internal `cmake_language(DEFER)` at the
end of `CMAKE_SOURCE_DIR`.

```text
<id>_configure → <id>_build → <id>_install
         ↑
   <id>  (INTERFACE — this is what you link)
```

| Target | Role |
|--------|------|
| `<id>` | `INTERFACE`. Depends on `<id>_install`. **This is what you link.** |
| `<id>_configure` | Nested CMake or Meson setup |
| `<id>_build` | Compile |
| `<id>_install` | Install into the shared prefix (skipped for `BUILDONLY`) |
| produced libs | `STATIC` / `SHARED` **IMPORTED** files under the prefix (or the build dir) |

| Nested configure | When |
|------------------|------|
| **Eager** | The component is not the `source` of any recorded wait edge |
| **Deferred** | It must wait on another node — configure runs at build time under `<id>_configure` |

The `INTERFACE` stub exists as soon as you call `buildmaster_component`.
You may `add_library(Vendor::Foo ALIAS foo)` in the same file.

BuildMaster assigns `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` and creates it.
There is no public builddir argument and no `ensure_build_dir`.

A **meta** uses the same anchor names (`<id>_install` waits on members)
but has no sources and installs nothing of its own — unless `REPACK`.

A **group** has none of those targets. It is a banner and a walk order.

---

## Dependencies and links

### `buildmaster_depend(source dest)`

Order-only edge. At materialize time `dest` resolves as the first match:

1. Registered component id → `<id>_install`
2. Registered **meta** id → `<id>_install`
3. Name matching `*_install` / `*_configure` / `*_build`
4. Existing CMake target

Otherwise: **FATAL** — unless the same pair is also a `buildmaster_link`
to a library spec or an on-disk archive. That dest is link-only.

A second *explicit* call with the same `(source, dest)` is **WARNING**
and a no-op. Unresolvable dest at finalize stays **FATAL**.

`BUILDONLY` pack waits use `_build` instead of `_install` for
that member. You do not write that by hand; `REPACK` does.

A group is not a graph node. `buildmaster_depend(foo grp-audio)` is FATAL.

### `buildmaster_link(source dest)`

Records a link on the component `INTERFACE`.

`dest` may be another component, a meta, an existing CMake target, an
archive that already exists on disk, or a library spec (`<name>` /
`<subdir>/<name>`) under the BM prefix.

**Link already waits.** `buildmaster_link(A B)` records the same
order-only edge as `buildmaster_depend(A B)` when `B` is a graph node,
even if `B` is registered later. You do not add a second
`buildmaster_depend(png zlib)` unless you enjoy the warning.

A spec or on-disk archive stays link-only: there is no wait target.

---

## Raw system libraries (`LINK`)

`LINK=` / `LINK={…}` are raw linker **names** (`shlwapi`, `ws2_32`, `m`).
They go on that id’s `INTERFACE` and propagate to whoever links it.

They are **not** graph nodes. A BM component belongs in
`buildmaster_link`, not in `LINK=`.

---

## Raw linker flags (`LINKFLAGS`)

`LINKFLAGS=` / `LINKFLAGS={…}` are raw linker **flags**
(`/FORCE:MULTIPLE`, `-Wl,-Bsymbolic`) for the **nested** cmake/meson
link of *that* component only.

They are folded into that id’s OPTIONS at finalize
(`CMAKE_EXE/SHARED/MODULE_LINKER_FLAGS` or Meson `c_link_args` /
`cpp_link_args`). They are **not** `target_link_options` on the
`INTERFACE`. A consumer of this id does **not** inherit them.

Platform groups: `WINDOWS`, `LINUX`, `MAC`, `UNIX` (`UNIX` = Linux +
macOS). A group that does not apply is skipped at INFO. An unknown
platform key is FATAL.

Meta and headers: WARNING + ignore (no nested link step). Put the flags
on the member that actually links.

This is how a leaf can need `-Bsymbolic` without poisoning the final
shared object of the product.

---

## Meta components

```cmake
buildmaster_meta(plugins "plugin pack")
buildmaster_meta_add(plugins opus vorbis)
buildmaster_link(engine plugins)
```

`buildmaster_meta_add` may run before `buildmaster_meta`.

A meta is an `INTERFACE` bucket. It has no `srcdir` and no nested
configure. `GIT=` / `FILES=` on a meta are FATAL. `LINKFLAGS=` on a
meta is WARNING + ignore. `TOOLCHAIN=` on a meta copies onto members
that did not pin one; an explicit child `TOOLCHAIN` wins.

`INDENT=` on a meta is WARNING and ignored. Put the meta in a
`buildmaster_group()` if you want the banner indent.

A group cannot be a meta member. `buildmaster_meta_add(plugins grp-audio)`
is FATAL.

---

## Groups

Outline only. No `INTERFACE`, no stages, no edges.

```cmake
buildmaster_group(grp-audio "Audio")
buildmaster_group_add(grp-audio opus speex maudio)

buildmaster_group(grp-filters "Filters")
buildmaster_group_add(grp-filters ssim mfilter)
```

`buildmaster_group(id [title])` stamps the banner. Empty title → the id.
`buildmaster_group_add` requires the group to already exist. Members may
be components, metas, or other groups. Duplicates are skipped. Self is
FATAL. Cycles are FATAL.

Finalize walks the forest, emits `banner:id:depth` then each member’s
`comp:id` so a nested configure sits under its banner. Depth becomes
the STATUS indent of that member (`INDENT=` on the leaf is overwritten
by the walk).

Groups are not consumption. Linking still goes through
`buildmaster_link` / `target_link_libraries` on the real ids.

---

## Component options

One optional trailing argument:

```text
KEY=value;KEY2=value with spaces;PC={VERSION=1.2.3;NAME=foo}
```

- First `=` in each pair splits key from value.
- `;` inside `{…}` is **not** a pair break.
- A trailing `;` is allowed (concatenation).
- Keys are case-insensitive, stored uppercase.
- Bare flag (`RENAME`, `WHOLE`, `BUILDONLY`, `STRIPRES`, `REPACK`)
  means `KEY=ON`.
- Unknown keys: **WARNING**, ignored.
- Extra positionals: **FATAL**.

| Key | Default | Notes |
|-----|---------|--------|
| `INDENT` / `INDENT_LEVEL` | `0` | Tabs after the log header. A group walk overwrites this |
| `TOOLCHAIN` | inherit | `gcc`, `clang`, `clang-cl`, `msvc` |
| `RENAME` | ON | Canonical archive name after install (or in the build dir if `BUILDONLY`) |
| `WHOLE` | OFF | Whole-archive link of **static** produced archives |
| `BUILDONLY` | OFF | Do not publish into the shared prefix |
| `STRIPRES` | ON | Strip `*.res` from static MSVC / clang-cl archives after `RENAME` |
| `REPACK` | OFF | **Meta only.** Merge every produced static of the members. Stem = meta id |
| `PC={…}` | off unless the group is present | Helper `.pc` for **this** prefix. Bare `PC` / `PC=ON` is FATAL |
| `LINK=` / `LINK={…}` | empty | Raw system linker names on the id `INTERFACE` |
| `LINKFLAGS=` / `LINKFLAGS={…}` | empty | Raw linker flags, nested link only |
| `GIT={…}` | off | Srcdir git. Empty group is WARNING. Meta + any op is FATAL |
| `FILES={…}` | off | Download / unpack. Meta + any group is FATAL |

`PC` on a meta is FATAL. `BUILDONLY` + enabled `PC` is FATAL.
`REPACK` on a component is FATAL.

---

## Build-only components and repack

`BUILDONLY` compiles (and optionally renames) **without** installing
into the shared prefix. The artifact lives in the hidden build
directory. That is why a `BUILDONLY` **shared** library cannot be a
`REPACK` member: the `.so` / `.dll` is not in the prefix and you have
no public path to it (FATAL).

`REPACK` belongs on a **meta**. The meta id is the output stem. Every
produced *static* archive of the member leaves is merged into one
prefix archive.

```cmake
buildmaster_component(enc-8  "enc 8"  "${ENC8_SRC}"  "" static enc "BUILDONLY")
buildmaster_component(enc-10 "enc 10" "${ENC10_SRC}" "" static enc "BUILDONLY")
buildmaster_meta(enc "encoder" "REPACK")
buildmaster_meta_add(enc enc-8 enc-10)
buildmaster_link(engine enc)
```

Wait edge is `_install` for a publishing leaf and `_build` for
`BUILDONLY`. Shared members that *do* install stay on the meta
`INTERFACE` (WARNING: they are not folded into the pack).

There is no public `buildmaster_repack`.

---

## Header-only components

Same factory, mode `headers`. Drop `<produced>` the same way.

- **No backend**, or headers + `BUILDONLY`: private island. Direct
  consumers get a quoted `-I` on *that* id’s nested configure only
  (CMake `CMAKE_{C,CXX}_FLAGS` and Meson `c_args` / `cpp_args`).
  It does **not** recurse through further BM components, runners, or
  `INTERFACE`. Several islands on one consumer accumulate several `-I`.
- **Backend and not `BUILDONLY`**: headers install into the shared
  prefix. The prefix `-I` already covers them; no extra propagation.

---

## Files (`FILES`)

Declarative download on `buildmaster_component`. Always cached under
`BUILDMASTER_DOWNLOADSDIR` (`FORCE` refetches). Unpack lives under
`${BUILDMASTER_BINDIR}/files/<NAME>/`, **before** nested configure
(eager ids included).

```cmake
buildmaster_component(
	amalgam
	"SQLite amalgamation"
	"${CMAKE_CURRENT_SOURCE_DIR}/unused-on-purpose"
	""
	static
	sqlite3
	"FILES={URL=https://example.invalid/sqlite.tar.gz;NAME=sqlite;UNPACK;SOURCE;SHA256=…}"
)
```

`SOURCE` (at most one group, requires `UNPACK`) **is** the srcdir.
The positional path is ignored by design (WARNING). Other unpacked
groups inject a private `-I` on that id only (same rule as a headers
island). `GIT={…}` + `SOURCE` is FATAL.

```bash
export BUILDMASTER_DOWNLOADSDIR="$HOME/.cache/buildmaster/downloads"
```

Point that cache *outside* `build/` or every wipe pays the network
again. There is no public `file_download`.

---

## Git (`GIT`)

Srcdir work on `buildmaster_component`. Flush order is fixed:
**FETCH → SWITCH → RESET → PATCH**. `PATCH=` files keep declaration
order. Relative `PATCH=` is from `CMAKE_CURRENT_SOURCE_DIR`.

```cmake
buildmaster_component(
	foo
	"Foo library"
	"${FOO_SRC}"
	""
	static
	foo
	"GIT={RESET;PATCH=0001-cmake4.patch;TITLE=Foo}"
)
```

`FETCH` / `RESET` are inner flags. Empty `GIT` / `GIT={}` is WARNING.
Post-install `reset --hard` + `clean -fd` runs only when a PATCH was
queued. RESET at the start of the group is how you survive a
half-configured tree; it is not mandatory.

Meta + any git op is FATAL. There is no public `create_git_*`.

---

## Helper pkg-config files (`PC`)

After install, write
`${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/<Name>.pc` for **this**
prefix so the next Meson node can find what you just built.

```text
PC={VERSION=1.2.3;NAME=foo}
```

Bare `PC` / `PC=ON` is FATAL. If the path already exists (upstream
already shipped a `.pc`), BuildMaster will not overwrite it (FATAL).
Use `PC={ENABLED=FALSE}` or drop the group. This is not a portable
package for `/usr`.

---

## Whole-archive linking (`WHOLE`)

`WHOLE` wraps that id’s produced **static** archives so a downstream
linker cannot drop “unused” objects (plugins, registration tables).
Put it on the component or on the meta you actually link.

---

## Stripping `.res` members (`STRIPRES`)

Default **on** for static MSVC / clang-cl archives. After `RENAME`,
members named `*.res` are removed so `/WHOLEARCHIVE` does not pull
duplicate resources (`LNK2005`). Silent on other toolchains.
`STRIPRES=OFF` if you really want those members.

---

## Subcomponent specs

`produced` and `buildmaster_link` dests accept `name` or
`subdir/name`. The spec is resolved under the shared prefix after
that id installs (or under the build dir if `BUILDONLY`). Ninja
gains a real `OUTPUT` path, not an empty stamp.

---

## Per-component toolchains

`TOOLCHAIN=gcc|clang|clang-cl|msvc` writes a nested toolchain file
(and a Meson native file) so one leaf can be `clang-cl` while the
parent is Clang. Profiles live under `toolchain/profiles/`.

A meta `TOOLCHAIN` copies onto members that did not pin one.

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

A hook is **not** an edge. It does not flip the component to
deferred. If the nested project must see a hook artifact during
setup, record `buildmaster_depend` so that id waits.

| You need the hook artifact… | Do this |
|-----------------------------|---------|
| at **compile** / install | Graph hook, or a component hook plus no configure-time check |
| at **nested configure** | A wait edge so the id is **deferred** |

---

## Orphan warnings

An id that is never linked, packed, or depended on produces one
**WARNING** at finalize. It is cheap insurance against a plugin you
built and then forgot to attach.

Membership in a group does **not** consume the id. A leaf that only
sits under a banner is still an orphan.

---

## Logging

```cmake
buildmaster_message(STATUS "Setting up Foo" 1)
```

There is no module argument. The module is always `USER`.
`-DBUILDMASTER_LOGLEVEL=DEBUG` (or `INFO` / `STATUS` / `WARNING` /
`LOWLEVEL` / `FATAL`). `BUILDMASTER_DEBUG` is ignored: it does not
select a log level and it does not select a runner.

`WARNING` and `FATAL` are never filtered.

`BUILDMASTER_LOGLEVEL` filters **BuildMaster lines**. It does not
decide whether `cmake --build` or `meson compile` print compiler
command lines. That is the next section.

---

## Verbosity of tool output

`BUILDMASTER_VERBOSE` is independent of `BUILDMASTER_LOGLEVEL`.
It selects how **nested compile** stages talk to the TTY, not which
`[BuildMaster/…]` lines exist.

| `BUILDMASTER_VERBOSE` | Compile stage (`*_build`) | Configure / install / git / files |
|-----------------------|---------------------------|-----------------------------------|
| OFF (default) | Silent env runner. Live TTY: BM headers only | Silent env runner |
| ON | Live env runner **and** `cmake --build --verbose` / `meson compile -v` | Unchanged (still silent unless the child itself is noisy) |

The silent runner always writes the full child log to disk and
replays nested `[BuildMaster/…]` lines live. On failure the complete
child output is dumped. Failures always surface.

`VERBOSE` does **not** mean “every CMake check and every Meson setup
line on the TTY”. That used to be the old `BUILDMASTER_DEBUG` runner
swap; that switch is gone. Enable `BUILDMASTER_VERBOSE` when you want
compiler command lines. Lower `BUILDMASTER_LOGLEVEL` when you want
more BM diagnostics.

```bash
# compiler / linker command lines only
cmake -DBUILDMASTER_VERBOSE=ON …

# BM policy lines (ignored keys, rename skips, …)
cmake -DBUILDMASTER_LOGLEVEL=INFO …

# both
cmake -DBUILDMASTER_VERBOSE=ON -DBUILDMASTER_LOGLEVEL=DEBUG …
```

Env `BUILDMASTER_VERBOSE=1` is accepted the same way as the cache
entry.

---

## Fail-fast

`BUILDMASTER_FAIL_FAST` stops later stages after a nested configure /
build / install dies, instead of letting Ninja discover the same
broken prefix twelve times.

---

## Compiler cache

If the parent job uses `ccache` / `sccache`, the env runners forward
the launchers into nested CMake and Meson so the cache is not a
parent-only luxury.

---

## Recursive usage

A component may be another project that itself `add_subdirectory`s
BuildMaster. Nested BM logs are replayed live (not dumped at the end
of a long configure). Do not assume hook order across trees.

Layout: BuildMaster and every DSL-driven dependency are **sibling**
directories. The registration `CMakeLists.txt` is not the nested
`srcdir`.

```
thirdparty/
	buildmaster/
	foo/
		src/
```

---

## Platform notes

Linux, Windows, and macOS are first-class. Paths with spaces and
Windows `C:\Users` are quoted / normalized before they reach a
nested compiler command. `LINKFLAGS` groups use `WINDOWS` / `LINUX` /
`MAC` / `UNIX` on purpose — not CMake’s `WIN32` / `APPLE`.

---

## Comparison

| Capability | FetchContent | ExternalProject_Add | BuildMaster |
|------------|:------------:|:-------------------:|:-----------:|
| Declarative graph (order-independent) | No | No | **Yes** |
| Eager *or* deferred nested configure | N/A | Build time only | **Yes** |
| Native Meson stages + shared prefix | No | Manual | **Yes** |
| Per-component toolchain | No | Manual | **Optional** |
| `LINK` / `LINKFLAGS` with different inheritance | Manual | Manual | **Yes** |
| `BUILDONLY` + static `REPACK` | No | Manual | **Yes** |
| Outline groups (banners + walk indent) | No | No | **`buildmaster_group`** |
| Cached, hashed downloads that survive `rm -rf build` | Partial | Manual | **`FILES=`** |
| Srcdir git flush + optional post-install reset | No | Manual | **`GIT=`** |
| Unified log + live nested BM lines | No | No | **Yes** |

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

If this saved you from a third `POST_BUILD` rename script, a star is
the polite nod. A well-aimed issue beats a vague “it broke”. Pull
requests that keep the DSL at ten commands are the ones that land.

I wrote this because the alternative was another private graph in
every product. Maintaining that difference takes evenings.

[Sponsor StormBytePP on GitHub](https://github.com/sponsors/StormBytePP)

Use it. Break it on purpose. Tell me which sentence in this file lied.
