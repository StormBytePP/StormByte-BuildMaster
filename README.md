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
| Six hours of “it works on my Linux box”, then 02:00 and a Windows CI that never heard of `pkg-config` | `REQUIRE_TOOL=pkgconfig` |
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
- [Extra tools (`REQUIRE_TOOL`)](#extra-tools-require_tool)
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
	"ENABLE_FOO=ON;WITH_TESTS=OFF"
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

The fourth argument is a **CMake list** of `KEY=value` (a single string
is a one-element list). It is backend-agnostic on purpose: write names
a human can read, not generator flags.

Six keys are idioms and are rewritten for the backend:

| Key | What happens |
|-----|----------------|
| `CFLAGS` / `CXXFLAGS` / `CPPFLAGS` / `LDFLAGS` | Appended to the parent job flags. They do **not** replace `CMAKE_*` or Meson `*_args`. |
| `INCLUDES` | Directory (relative to `srcdir` unless absolute) → compile `-I`. |
| `DEFINITIONS` | `FOO` or `FOO=1` → compiler `-D`. |

Everything else is forwarded as `-DKEY=value` to the nested **CMake**
configure **and** to the nested **Meson** setup (Meson also uses `-D`,
not `-d`). A leading `-D`, `-d` or `/D` on the key is stripped, so
`-DENABLE_FOO=ON` and `ENABLE_FOO=ON` are the same pair. Prefer the
form without the prefix.

These options are private to that nested configure / compile. They are
not `INTERFACE` on `<id>` and they are not `ENV{CFLAGS}`. A `headers`
component with no backend (`none`) ignores the list.

Optional policy string (one trailing argument):

```cmake
buildmaster_component(
	mylib
	"My Library"
	"${CMAKE_SOURCE_DIR}/thirdparty/mylib/src"
	"ENABLE_FOO=ON"
	static
	mylib
	"TOOLCHAIN=clang-cl;WHOLE;LINK={shlwapi;ws2_32};PC={VERSION=1.2.3;NAME=mylib};REQUIRE_TOOL=pkgconfig"
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

`ninja` and the archiver come up with the tools tree. `cmake`, `meson`,
`git`, and `file` start the first time a component actually needs them.
Extra tools (`pkgconfig`, …) start only from `REQUIRE_TOOL`.

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

A group is not a graph node. `buildmaster_depend(foo grp-audio)` is FATAL.

### `buildmaster_link(source dest)`

Records a link on the component `INTERFACE`.

`dest` may be another component, a meta, an existing CMake target, an
archive that already exists on disk, or a library spec (`<name>` /
`<subdir>/<name>`) under the BM prefix.

**Link already waits.** `buildmaster_link(A B)` records the same
order-only edge as `buildmaster_depend(A B)` when `B` is a graph node,
even if `B` is registered later.

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

They are folded into that id’s OPTIONS at finalize. They are **not**
`target_link_options` on the `INTERFACE`. A consumer of this id does
**not** inherit them.

Platform groups: `WINDOWS`, `LINUX`, `MAC`, `UNIX` (`UNIX` = Linux +
macOS). A group that does not apply is skipped at INFO. An unknown
platform key is FATAL.

Meta and headers: WARNING + ignore. Put the flags on the member that
actually links.

---

## Meta components

```cmake
buildmaster_meta(plugins "plugin pack")
buildmaster_meta_add(plugins opus vorbis)
buildmaster_link(engine plugins)
```

`buildmaster_meta_add` may run before `buildmaster_meta`.

A meta is an `INTERFACE` bucket. No `srcdir`, no nested configure.
`GIT=` / `FILES=` on a meta are FATAL. `LINKFLAGS=` on a meta is
WARNING + ignore. `TOOLCHAIN=` copies onto members that did not pin
one. `REQUIRE_TOOL=` on a meta is accepted.

A group cannot be a meta member.

---

## Groups

Outline only. No `INTERFACE`, no stages, no edges.

```cmake
buildmaster_group(grp-audio "Audio")
buildmaster_group_add(grp-audio opus speex)
```

`buildmaster_group_add` requires the group to already exist. Members may
be components, metas, or other groups. Cycles and id clashes are FATAL.

Groups are not consumption. Linking still goes through
`buildmaster_link` on the real ids.

---

## Component options

One optional trailing argument:

```text
KEY=value;KEY2=value with spaces;PC={VERSION=1.2.3;NAME=foo}
```

- First `=` in each pair splits key from value.
- `;` inside `{…}` is **not** a pair break.
- A trailing `;` is allowed.
- Keys are case-insensitive, stored uppercase.
- Bare flag (`RENAME`, `WHOLE`, `BUILDONLY`, `STRIPRES`, `REPACK`,
  `REQUIRE_TOOL`) is accepted by the splitter.
- Unknown keys: **WARNING**, ignored.
- Extra positionals: **FATAL**.

| Key | Default | Notes |
|-----|---------|-------|
| `TOOLCHAIN` | parent | Profile name (`gcc`, `clang`, `clang-cl`, `msvc`) |
| `RENAME` | ON | Normalize variant archive names after install |
| `WHOLE` | OFF | Whole-archive the produced statics |
| `STRIPRES` | ON | Strip `*.res` from static MSVC / clang-cl archives |
| `BUILDONLY` | OFF | Build without publishing to the shared prefix |
| `REPACK` | OFF | Meta only. Merge member statics into one prefix archive |
| `PC={…}` | off | Write a helper `.pc` after install. Does **not** demand pkg-config |
| `LINK=` / `LINK={…}` | empty | Raw system linker names on the INTERFACE |
| `LINKFLAGS=` / `LINKFLAGS={…}` | empty | Raw flags for the nested link only |
| `GIT={…}` | empty | Fetch / switch / reset / patch the srcdir |
| `FILES={…}` | empty | Download / unpack / optional SOURCE tree |
| `REQUIRE_TOOL=` / `REQUIRE_TOOL={…}` | empty | Demand an extra tool (`pkgconfig`, …) |
| `INDENT=` | ignored | WARNING. Use `buildmaster_group` |

`REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}` is WARNING and
ignored. A name that is not a known extra is FATAL.

---

## Build-only components and repack

`BUILDONLY` keeps artifacts under the component build dir. They never
land in the shared prefix.

`buildmaster_meta(id title "REPACK")` plus `buildmaster_meta_add`
merges every produced **static** archive of the member leaves into one
prefix archive named after the meta id. Shared members stay INTERFACE
(WARNING). `REPACK` on `buildmaster_component` is FATAL.

---

## Header-only components

Mode `headers`. No produced spec.

- Backend + not `BUILDONLY`: headers install into the shared prefix.
- No backend (`none`) or `BUILDONLY` headers: private island. Direct
  consumers get a quoted `-I` on *that* id’s nested compile only.

---

## Files (`FILES`)

```cmake
"FILES={URL=https://example.com/foo.tar.xz;NAME=foo.tar.xz;SHA256=…;UNPACK;SOURCE}"
```

Cached under `BUILDMASTER_DOWNLOADSDIR`. Meta + any `FILES` key is FATAL.
`GIT={…}` + `SOURCE` is FATAL (two owners of the same tree).

---

## Git (`GIT`)

```cmake
"GIT={FETCH;SWITCH=release/1.2;RESET;PATCH=patches/foo.patch}"
```

Order is fixed: FETCH → SWITCH → RESET → PATCH. Empty `GIT` / `GIT={}`
is WARNING. Meta + a real git op is FATAL.

---

## Helper pkg-config files (`PC`)

```cmake
"PC={VERSION=1.2.3;NAME=mylib;DESCRIPTION=My library}"
```

Writes `${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/<Name>.pc` after
install. FATAL if that path already exists. Not a portable package.

`PC=` only **writes** the file. It does not demand the `pkgconfig`
extra. The next Meson or Autotools leaf that *reads* `.pc` files is
your problem — see [`REQUIRE_TOOL`](#extra-tools-require_tool).

---

## Extra tools (`REQUIRE_TOOL`)

This is the 02:00 clause.

You spent the evening on Linux. Every Meson leaf found `libfoo` through
a `.pc` you just wrote. You push. Windows CI does not have `pkg-config`.
The leaf that “just works” locally dies in `dependency('foo')` and you
debug a missing *tool*, not a missing library.

`REQUIRE_TOOL` exists so that does not happen twice.

```cmake
buildmaster_component(
	ffmpeg
	"FFmpeg"
	"${CMAKE_SOURCE_DIR}/thirdparty/ffmpeg"
	""
	static
	avcodec
	"REQUIRE_TOOL=pkgconfig;PC={VERSION=7.0;NAME=libavcodec}"
)
```

- One id: `REQUIRE_TOOL=pkgconfig`
- Several: `REQUIRE_TOOL={pkgconfig;…}`
- Empty / bare / `{}`: WARNING, no demand
- Unknown id: **FATAL**. BuildMaster will not pretend the system binary
  with the same name is “the extra”. If it is not in
  `BUILDMASTER_TOOLS_EXTRA_KNOWN` and `tools/extra/<id>/`, it does not
  exist.

`pkgconfig` (this release) still prefers a working system
pkg-config / pkgconf. Only if that probe fails does it build the
bundled tree (the Windows case, and any runner that shipped a broken
one).

The extra is demanded at **register**, so it exists before nested
configure. A second `REQUIRE_TOOL=pkgconfig` is a no-op.

This release ships one extra. More extras are the same contract: a
folder under `tools/extra/<id>/`, one line in
`BUILDMASTER_TOOLS_EXTRA_KNOWN`, and `_bm_extra_<id>_init`. When that
happens you will still write `REQUIRE_TOOL=…`. You will not get a new
public command.

`BUILDMASTER_INITIALIZE_EXTRA_TOOLS` is gone. Do not set it.

---

## Whole-archive linking (`WHOLE`)

`WHOLE` on a static component (or a meta) wraps produced archives so
the linker cannot drop unreferenced objects (plugins, statically
registered codecs). Shared / headers: INFO + ignore.

---

## Stripping `.res` members (`STRIPRES`)

Default ON for static MSVC / clang-cl archives. After `RENAME`,
`*.res` members are removed so `/WHOLEARCHIVE` does not duplicate
resources. Other toolchains: silent no-op.

---

## Subcomponent specs

`produced` is `<name>` or `<subdir>/<name>`. Names are canonical
(post-`RENAME`). `buildmaster_link(consumer subdir/name)` links that
archive only.

---

## Per-component toolchains

`TOOLCHAIN=gcc|clang|clang-cl|msvc`. Nested configure, build and
install use that profile. A meta `TOOLCHAIN` copies onto members that
did not pin one.

Binutils in the profile (`ar`, `ranlib`) are resolved to absolute
paths before the component toolchain file is written. Nested CMake
must not run `ar` relative to the component bindir.

---

## Hooks

```cmake
buildmaster_hook_component(mylib my_after_mylib after_mylib)
buildmaster_hook_graph(my_after_graph after_graph)
```

`fn` must exist at registration. Alias is the only order key (ASCII
ascending). A hook is not an edge and does not flip eager / deferred.

---

## Orphan warnings

A component or meta that nothing consumes (`buildmaster_link` /
`buildmaster_depend` / host link / host `DEPENDS` / consumed `REPACK`
meta) is WARNING after finalize. Fix the graph or accept the noise.

---

## Logging

`buildmaster_message(<level> "<text>" [<indent>])`. Module is always
`USER`. Levels: `STATUS`, `INFO`, `WARNING`, `DEBUG`, `LOWLEVEL`,
`FATAL`. `WARNING` and `FATAL` are never filtered.

`BUILDMASTER_LOGLEVEL` selects how much is printed.
`BUILDMASTER_LOG_NOCOLOR=ON` turns ANSI off.

---

## Verbosity of tool output

`BUILDMASTER_VERBOSE=ON` is nested compile `--verbose` / `-v` **only**.
It is not a log level. It is not “print every tool’s configure”.
Tools print `Setting up tools: <name>` when they actually start.

`BUILDMASTER_VERBOSE` also enables the configure report after graph
hooks (`BuildMaster <version> Configuration:`). That is still not
`-v` for every extra.

---

## Fail-fast

`BUILDMASTER_FAIL_FAST` (env or `-D`; truthy `1` / `ON` / `TRUE` /
`YES`). On stage failure a marker is written and later stages skip.
Default OFF so independent leaves can still warm a compiler cache.

---

## Compiler cache

Parent `CMAKE_{C,CXX}_COMPILER_LAUNCHER`, `CCACHE_DIR` and
`SCCACHE_DIR` are forwarded into nested CMake and Meson.

---

## Recursive usage

`add_subdirectory(buildmaster)` from a nested project is safe. The
first bootstrap owns `BUILDMASTER_ROOT` and the toolchain dump. A
second tree loads the parent helpers and returns. Match versions
across submodules; a mismatch is WARNING.

Always `add_subdirectory(buildmaster)`. Do not special-case “I am
already inside BM”.

---

## Platform notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Generator | Ninja | Ninja | Ninja |
| Meson | yes | yes | yes |
| `clang-cl` / `msvc` | — | — | profiles |
| pkg-config on PATH | usually | often | **often not** |

Windows is why `REQUIRE_TOOL=pkgconfig` exists. Linux hiding the same
bug is not a feature.

---

## Comparison

| | FetchContent | ExternalProject | BuildMaster |
|--|--------------|-----------------|-------------|
| Configure time | yes | no (build time) | eager when the graph allows |
| Meson | you write it | you write it | first-class |
| Shared prefix + `.pc` | DIY | DIY | prefix + optional `PC=` |
| Graph edges | include order | `DEPENDS` | `depend` / `link` |
| Order-independent declare | no | no | yes |
| Extra host tools | hope PATH | hope PATH | `REQUIRE_TOOL` |

---

## Self-tests

From the BuildMaster repo:

```sh
rm -rf build/harness && cmake -S .github/tests/harness -B build/harness -G Ninja \
	&& cmake --build build/harness --target run_buildmaster_smoke \
	&& cmake --build build/harness --target run_buildmaster_negative
```

Consumer (public API only):

```sh
cmake --build build/harness --target run_buildmaster_consumer
```

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
