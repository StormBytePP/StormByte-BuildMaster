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

Want to say “I need to link my app (or my lib) against something BuildMaster
already built — freetype, harfbuzz, libpng, the library you wrote last
Tuesday — and **not** keep a spreadsheet of everything *that* library
quietly pulls in”? That is the sentence this file is for.

One well-behaved CMake library? `FetchContent` is enough.

Twelve upstreams — some CMake, some Meson, some that install `zsd.lib` when
you asked for `z.lib`, some that must configure *after* another prefix
exists, some that only work under `clang-cl`, and a static plugin pack the
linker will drop unless you wrap it in `--whole-archive` — and you already
have a private orchestration layer. Usually it is `add_custom_command`,
hardcoded paths, and “remember to declare zlib before libpng”. Then you
link `libpng` and Windows reminds you about `shlwapi` because somebody
three levels down needed it and nobody wrote it down.

Those weeks do not make you a worse programmer. They make you the person
this file is for.

BuildMaster is that layer, written once:

| You stop writing… | You get… |
|-------------------|----------|
| “Declare A before B or configure explodes” | Order-independent registration |
| `ExternalProject` that only configures at *build* time | Eager configure when the graph allows it |
| A wait edge *and* a link edge for the same pair | `buildmaster_link` already waits |
| “Link png, and also freetype, and also harfbuzz, and also whatever they grew last week” | `links/` + `buildmaster_link(app png)` |
| A second `add_library(Foo::Bar ALIAS …)` in every consumer | `ALIAS=Foo::Bar` on the component |
| Hand-rolled Meson `setup` that misses `.pc` files | Same prefix, `PKG_CONFIG_PATH`, compilers, cache launchers |
| `POST_BUILD` rename scripts per MSVC flavor | `RENAME` (default on) |
| `--whole-archive` soup in the parent | `WHOLE` on a component or a **meta** |
| `LNK2005` / duplicate `.res` after `/WHOLEARCHIVE` | `STRIPRES` on static MSVC / clang-cl archives (default on) |
| `shlwapi` on every consumer because a static `.lib` does not record it | `LINK={…}` on the producer (or the meta) |
| `/FORCE:MULTIPLE` on the **parent** because one leaf needed it | `LINKFLAGS={…}` on **that** leaf (not inherited) |
| Parent `-flto` / `/GL` leaking into a leaf that cannot probe under LTO | `IPO=off` on that leaf (or `IPO=fat` when you still need real objects) |
| Hand-written `.pc` so the next Meson node finds this prefix | `PC={…}` on the leaf |
| Six hours of “it works on my Linux box”, then 02:00 and a Windows CI that never heard of `pkg-config` | `REQUIRE_TOOL=pkgconfig` |
| A submodule whose `meson.build` / `CMakeLists.txt` lives one folder down | `SOURCE=libfoo` (same isolation as `GIT ROOT=`) |
| Dual markers and a private `_bm_backend_*_create` | `BACKEND=cmake` / `BACKEND=meson` |
| `cmake_language(DEFER)` so a summary line appears *after* the graph | Hooks |
| Waiting on a slow tarball every `rm -rf build` | `BUILDMASTER_DOWNLOADSDIR` outside the build tree |
| Four public git helpers plus an `include()` | `GIT={…}` on the component |
| A download target plus a prerequisite edge | `FILES={…}` on the component |
| Manual `INDENT=` so related leaves line up in the log | `buildmaster_group` |
| `BUILDONLY=` because “maybe I can turn it off later” | `NOINSTALL` (a flag, not a switch) |

The cost is a short public API. The payoff is a parent tree that looks like
a product, not a build blog.

---

## Table of contents

- [Quick start](#quick-start)
- [Ten commands](#ten-commands)
- [How a component works](#how-a-component-works)
- [Dependencies and links](#dependencies-and-links)
- [Aliases (`ALIAS`)](#aliases-alias)
- [Exported links (`links/`)](#exported-links-links)
- [Raw system libraries (`LINK`)](#raw-system-libraries-link)
- [Raw linker flags (`LINKFLAGS`)](#raw-linker-flags-linkflags)
- [Meta components](#meta-components)
- [Groups](#groups)
- [Component options](#component-options)
- [Source tree (`SOURCE`)](#source-tree-source)
- [Backend (`BACKEND`)](#backend-backend)
- [No-install components and repack](#no-install-components-and-repack)
- [Header-only components](#header-only-components)
- [Executables](#executables)
- [Files (`FILES`)](#files-files)
- [Git (`GIT`)](#git-git)
- [Helper pkg-config files (`PC`)](#helper-pkg-config-files-pc)
- [Extra tools (`REQUIRE_TOOL`)](#extra-tools-require_tool)
- [Whole-archive linking (`WHOLE`)](#whole-archive-linking-whole)
- [Stripping `.res` members (`STRIPRES`)](#stripping-res-members-stripres)
- [Interprocedural optimization (`IPO`)](#interprocedural-optimization-ipo)
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
	"ALIAS=My::Lib"
)

target_link_libraries(MyApp PRIVATE mylib)
# or: target_link_libraries(MyApp PRIVATE My::Lib)
```

Same factory, a tool that uses that library. The nested tree must still
`target_link_libraries` / `link_with` the archive — BM waits and puts
`-I`/`-L` on the nested compile; it does not invent a CMake target
inside someone else’s `CMakeLists.txt`:

```cmake
buildmaster_component(
	mytool
	"My Tool"
	"${CMAKE_SOURCE_DIR}/thirdparty/mytool/src"
	""
	executable
	mytool
)

buildmaster_link(mytool mylib)
```

No build directory. No out-variable. No generated fragment to `include()`.
The backend is inferred from `srcdir` (`CMakeLists.txt` vs `meson.build`),
after `SOURCE=` if you wrote one. Stage targets and the `INTERFACE` stub
named `mylib` exist when registration returns; produced paths are filled
in at the end of `CMAKE_SOURCE_DIR`.

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
	"TOOLCHAIN=clang-cl;WHOLE;ALIAS=My::Lib;LINK={shlwapi;ws2_32};PC={VERSION=1.2.3;NAME=mylib};REQUIRE_TOOL=pkgconfig"
)
```

A leaf that must not inherit the parent’s LTO:

```cmake
buildmaster_component(
	tinyprobe
	"Tiny probe lib"
	"${CMAKE_SOURCE_DIR}/thirdparty/tinyprobe/src"
	""
	static
	tinyprobe
	"IPO=off"
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
| `buildmaster_component(id title srcdir options mode produced [optstr])` | Factory. Backend from `srcdir` (after `SOURCE=` / `BACKEND=`). No builddir |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest [dest…])` | Link on the component `INTERFACE` **and** a depend edge when `dest` is a graph node. Aliases resolve to ids |
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
| `<id>_install` | Publish into the shared prefix when the id is not `NOINSTALL`. Always runs oficios (`RENAME`, outputs, `STRIPRES`, `PC`) on the artifact that exists (prefix or BUILDDIR). Does **not** call `cmake --install` / `meson install` under `NOINSTALL` |
| produced libs | `STATIC` / `SHARED` **IMPORTED** files under the prefix (or the build dir) |
| produced exe | File under `BINDIR` (or the build dir). No `IMPORTED` executable on `<id>` |

| Nested configure | When |
|------------------|------|
| **Eager** | The component is not the `source` of any recorded wait edge |
| **Deferred** | It must wait on another node — configure runs at build time under `<id>_configure` |

The `INTERFACE` stub exists as soon as you call `buildmaster_component`.
`ALIAS=` on the optstr is applied at that moment. You may still write
`add_library(Vendor::Foo ALIAS foo)` yourself; a clash with a different
target is FATAL.

BuildMaster assigns `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` and creates it.
There is no public builddir argument and no `ensure_build_dir`.

`ninja` comes up with the tools tree. The archiver is the active
`TOOLCHAIN=` profile (`CMAKE_AR`, Meson `[binaries] ar` / `ld`), not a
tool. `cmake`, `meson`, `git`, and `file` start the first time a
component actually needs them. Extra tools (`pkgconfig`, …) start only
from `REQUIRE_TOOL`.

---

## Dependencies and links

### `buildmaster_depend(source dest)`

Order-only edge. At materialize time `dest` resolves as the first match:

1. Registered component id → `<id>_install` (publishing **and**
   `NOINSTALL`: oficios on the produced stem)
2. Registered **meta** id → `<id>_install`
3. Name matching `*_install` / `*_configure` / `*_build`
4. Existing CMake target

Otherwise: **FATAL** — unless the same pair is also a `buildmaster_link`
to a library spec or an on-disk archive. That dest is link-only.

A second *explicit* call with the same `(source, dest)` is **WARNING**
and a no-op. Unresolvable dest at finalize stays **FATAL**.

A group is not a graph node. `buildmaster_depend(foo grp-audio)` is FATAL.

Aliases passed as `source` or `dest` resolve to the id first.

### `buildmaster_link(source dest [dest…])`

Records a link on the component `INTERFACE`. Several dests on one call
are the same contract applied once each. A dest repeated in the same
call is WARNING + skip.

`dest` may be another component, a meta, an alias of either, an existing
CMake target, an archive that already exists on disk, or a library spec
(`<name>` / `<subdir>/<name>`) under the BM prefix.

**Link already waits.** `buildmaster_link(A B)` records the same
order-only edge as `buildmaster_depend(A B)` when `B` is a graph node,
even if `B` is registered later.

`buildmaster_link` to a `NOINSTALL` dest is FATAL. Wait with
`buildmaster_depend`, or publish the archives through a `REPACK` meta
or a static `REPACK` component.

---

## Aliases (`ALIAS`)

```cmake
"ALIAS=Vendor::Foo"
"ALIAS={Vendor::Foo;Vendor::FooLegacy}"
```

After the INTERFACE stub exists, BuildMaster does
`add_library(<alias> ALIAS <id>)` for each name. Valid on a component
and on a meta.

If `<alias>` already maps to a *different* target: **FATAL** with a BM
sentence, not the raw CMake one. Mapping again to the same id is a
no-op.

`buildmaster_link` / `buildmaster_depend` accept the alias. The edge is
stored under the real id.

---

## Exported links (`links/`)

This is the “I only wanted png” clause.

Every materialized component and every created meta writes one file:

```text
${BUILDMASTER_LINKS_DIR}/<sanitized-id>.cmake
```

`BUILDMASTER_LINKS_DIR` sits next to `scripts/` under the **trunk**
bindir. It is propagated and dumped into the toolchain file, so a
nested cmake — another process, another repo — still sees the same
directory. There is one BuildMaster. There is one `links/`.

The file is generated from a template (same idea as the git / cmake
stage scripts). It carries:

- the id and its `ALIAS=` names
- the prefix include dir (or the `NOINSTALL` build dir)
- linker **names** plus `-L` (not raw `.a` / `.lib` paths: those
  have no Ninja rule in a parent that never registered the leaf)
- BM dests recorded with `buildmaster_link`

A later tree `include()`s those files and can write:

```cmake
buildmaster_component(
	myapp_plugin
	"My plugin"
	"${CMAKE_SOURCE_DIR}/plugin"
	""
	static
	myplugin
)

buildmaster_link(myapp_plugin freetype)
```

If freetype, harfbuzz and libpng were all declared with
`buildmaster_component` (or a meta) in the tree that built them, the
plugin does not list harfbuzz and libpng. The `links/freetype.cmake`
file already knows.

Rules that keep this honest:

- Only BM nodes go into `links/`. A raw `target_link_libraries` inside
  a nested `CMakeLists.txt` is invisible. If the nested project is
  itself a BM graph, use `buildmaster_link` there too.
- Same id declared again is first-wins. Configure prints
  `Skipping configure of <title> — already registered as…` or
  `already built by…` and does not compile it twice. Reuse is valid
  only if after `include()` the TARGET `<id>` exists. Version
  comparison is a 2.1 problem.
- `buildmaster_clean` deletes `links/` with the rest of the bindir.
- System libs (`shlwapi`, `m`) stay on `LINK=` / `buildmaster_link`
  as raw names. They ride along on the INTERFACE; they are not BM ids.

Use BM for the whole chain and the parent stays one line. Mix a
hand-rolled leaf in the middle and you are back to writing dests
yourself — that is fair.

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
actually links. `executable` keeps them — that *is* a nested link.

---

## Meta components

```cmake
buildmaster_meta(plugins "plugin pack" "ALIAS=Vendor::Plugins")
buildmaster_meta_add(plugins opus vorbis)
buildmaster_link(engine plugins)
```

`buildmaster_meta_add` may run before `buildmaster_meta`.

A meta is an `INTERFACE` bucket. No `srcdir`, no nested configure.
`GIT=` / `FILES=` / `SOURCE=` / `BACKEND=` on a meta are FATAL.
`LINKFLAGS=` on a meta is WARNING + ignore. `TOOLCHAIN=` copies onto
members that did not pin one. `IPO=` does the same: members that omit
`IPO=` inherit the meta; a member that wrote `IPO=` keeps its own
value (no FATAL if two metas disagree). `REQUIRE_TOOL=` on a meta is
accepted. `NOINSTALL` on a meta is prevalent: finalize stamps every
member. `ALIAS=` on a meta is the same contract as on a component.

A group cannot be a meta member.

---

## Groups

Outline only. No `INTERFACE`, no stages, no edges.

```cmake
buildmaster_group(grp-audio "Audio")
buildmaster_group_add(grp-audio opus speex)
```

`buildmaster_group_add` requires the group to already exist. Members
may be components, metas, or other groups. Cycles and id clashes are
FATAL.

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
- Bare flag (`RENAME`, `WHOLE`, `NOINSTALL`, `STRIPRES`, `REPACK`,
  `REQUIRE_TOOL`, `IPO`) is accepted by the splitter.
- `BUILDONLY` is accepted by the splitter only so the parser can FATAL
  (`use NOINSTALL`).
- Unknown keys: **WARNING**, ignored.
- Extra positionals: **FATAL**.

| Key | Default | Notes |
|-----|---------|-------|
| `TOOLCHAIN` | parent | Profile name (`gcc`, `clang`, `clang-cl`, `msvc`) |
| `IPO` / `IPO=` / `IPO=on\|off\|fat` | inherit | Per-id LTO. Omitted follows the parent. Invalid value is FATAL |
| `RENAME` | ON | Normalize variant archive / binary names after install |
| `WHOLE` | OFF | Whole-archive the produced statics |
| `STRIPRES` | ON | Strip `*.res` from static MSVC / clang-cl archives |
| `NOINSTALL` | OFF | Build without publishing to the shared prefix. Flag, not a switch |
| `BACKEND` | detect | `cmake` or `meson` when both markers exist |
| `SOURCE` | (srcdir) | Subtree under the positional `srcdir`. Applied **before** detect |
| `ALIAS=` / `ALIAS={…}` | empty | `add_library(alias ALIAS id)` after the stub |
| `REPACK` | OFF | Meta, or a **static** component: merge NOINSTALL static dests into the prefix archive |
| `PC={…}` | off | Write a helper `.pc` after install. Does **not** demand pkg-config. FATAL on `executable` |
| `LINK=` / `LINK={…}` | empty | Raw system linker names on the INTERFACE |
| `LINKFLAGS=` / `LINKFLAGS={…}` | empty | Raw flags for the nested link only |
| `GIT={…}` | empty | Fetch / switch / reset / patch. `ROOT=` uses the same isolation as `SOURCE=` |
| `FILES={…}` | empty | Download / unpack / optional inner `SOURCE` tree (not the optstr) |
| `REQUIRE_TOOL=` / `REQUIRE_TOOL={…}` | empty | Demand extra tool (`pkgconfig`, …) |
| `INDENT=` | ignored | WARNING. Use `buildmaster_group` |

`REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}` is WARNING and
ignored. A name that is not a known extra is FATAL.

`NOINSTALL=` and `NOINSTALL=ON` enable with WARNING
(`write NOINSTALL, not NOINSTALL=…`). `NOINSTALL=OFF` is FATAL
(`omit the key to install`).

Bare `IPO` and `IPO=` mean thin LTO on. See
[Interprocedural optimization (`IPO`)](#interprocedural-optimization-ipo).

---

## Source tree (`SOURCE`)

Tired of a git submodule whose `meson.build` or `CMakeLists.txt` sits
in a subfolder and not at the tree root? That is what `SOURCE=` is for.

```cmake
buildmaster_component(
	foo
	"Foo"
	"${CMAKE_SOURCE_DIR}/thirdparty/foo/src"
	""
	static
	foo
	"SOURCE=libfoo"
)
```

`SOURCE=` is **always** under the positional `srcdir`. A leading `/`
is still a child of that srcdir (`/libfoo` → `srcdir/libfoo`), not an
absolute path on the host. Escape above the component srcdir — or
above the host `CMAKE_SOURCE_DIR` — is FATAL **before** any existence
probe. After that check, a missing directory is FATAL.

Detect runs on the resolved tree. Dual markers there are still FATAL
unless you also write `BACKEND=`.

This is not `FILES={…;SOURCE}`. FILES `SOURCE` *replaces* the srcdir
after an unpack. The optstr `SOURCE=` *selects a child* of the srcdir
you already passed.

---

## Backend (`BACKEND`)

When `srcdir` (after `SOURCE=`) contains both `CMakeLists.txt` and
`meson.build`, detect is FATAL. Say which generator you meant:

```cmake
"BACKEND=meson"
```

Allowed names live in `BUILDMASTER_FACTORY_BACKENDS` (`cmake`, `meson`
in this release). Empty or unknown: FATAL. There is no `BACKEND=none`
— that is `headers` without a backend, or `NOINSTALL` when you truly
have no generator.

---

## No-install components and repack

`NOINSTALL` keeps artifacts under the component build dir. They never
land in the shared prefix. The `<id>_install` target still exists: it
does not run `cmake --install` / `meson install`, but it **does** run
oficios (`RENAME` included) so the BUILDDIR stem is the produced name
(`foo.lib`, not `foo-static.lib`). REPACK and `buildmaster_depend`
wait on that `_install`, not on `_build`.

`buildmaster_meta(id title "REPACK")` plus `buildmaster_meta_add`
merges every produced **static** archive of the member leaves into one
prefix archive named after the meta id. Shared members stay INTERFACE
(WARNING). `NOINSTALL` + shared as a `REPACK` member is FATAL.

`REPACK` on a **static** `buildmaster_component` merges first-level
`depend`/`link` dests that are NOINSTALL static into that component’s
already-installed prefix archive. Headers / executable + `REPACK` on
the same id is FATAL. An `executable` dest of a REPACK publisher is
skipped (INFO), not a member. Shared + `REPACK` on a component is
WARNING + skip. Zero static members is FATAL. `REPACK` + `NOINSTALL`
on the same id is FATAL.

`BUILDONLY` is gone. Write `NOINSTALL`.

---

## Header-only components

Mode `headers`. No produced spec.

- Backend + not `NOINSTALL`: headers install into the shared prefix.
- No backend (`none`) or `NOINSTALL` headers: private island. Direct
  consumers get a quoted `-I` on *that* id’s nested compile only.

---

## Executables

Mode `executable`. Produced spec is a binary stem, not `libfoo.a`.

The file lands under `BUILDMASTER_INSTALL_BINDIR` (`bin/<stem>` on Unix,
`bin/<stem>.exe` on Windows). `NOINSTALL` keeps it under the component
BUILDDIR.

`<id>` is still an `INTERFACE` stub. Do not `target_link_libraries(host mytool)`
expecting symbols from the binary. Run the file after `<id>_install`.
The nested project is what actually links libraries (`find_library` /
`link_with`); `buildmaster_link(mytool mylib)` is the wait edge and the
parent INTERFACE, not a target inside the upstream `CMakeLists.txt`.

`RENAME` (default ON) normalizes variant binary names onto the produced
stem. `WHOLE` / `STRIPRES` / enabled `PC={…}` do not apply (`PC` ENABLED
is FATAL). `REPACK` on the executable itself is FATAL.

---

## Files (`FILES`)

```cmake
"FILES={URL=https://example.com/foo.tar.xz;NAME=foo.tar.xz;SHA256=…;UNPACK;SOURCE}"
```

Cached under `BUILDMASTER_DOWNLOADSDIR`. Meta + any `FILES` key is FATAL.
`GIT={…}` + FILES `SOURCE` is FATAL (two owners of the same tree).

---

## Git (`GIT`)

```cmake
"GIT={FETCH;SWITCH=release/1.2;RESET;PATCH=patches/foo.patch;ROOT=src}"
```

Order is fixed: FETCH → SWITCH → RESET → PATCH. Empty `GIT` / `GIT={}`
is WARNING. Meta + a real git op is FATAL.

`ROOT=` is the same isolation contract as optstr `SOURCE=`: always under
the component srcdir, escape FATAL before existence, host repo FATAL.
Operations never run in the parent project.

---

## Helper pkg-config files (`PC`)

```cmake
"PC={VERSION=1.2.3;NAME=mylib;DESCRIPTION=My library}"
```

Writes `${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/<Name>.pc` after install.
FATAL if that path already exists. Not a portable package.

`PC=` only **writes** the file. It does not demand the `pkgconfig`
extra. The next Meson or Autotools leaf that *reads* `.pc` files is
your problem — see [`REQUIRE_TOOL`](#extra-tools-require_tool).

`NOINSTALL` + enabled `PC=` is FATAL (no shared prefix).
`executable` + enabled `PC=` is FATAL.

---

## Extra tools (`REQUIRE_TOOL`)

You spent the evening on Linux. Every Meson leaf found `libfoo` through
a `.pc` you just wrote. You push. Windows CI does not have `pkg-config`.
The leaf that “just works” locally dies in `dependency('foo')` and you
debug a missing *tool*, not a missing library.

`REQUIRE_TOOL` exists so that does not happen twice.

```cmake
buildmaster_component(
	codecpack
	"Codec pack"
	"${CMAKE_SOURCE_DIR}/thirdparty/codecpack"
	""
	static
	codecpack
	"REQUIRE_TOOL=pkgconfig;PC={VERSION=1.0;NAME=codecpack}"
)
```

- One id: `REQUIRE_TOOL=pkgconfig`
- Several: `REQUIRE_TOOL={pkgconfig;…}`
- Empty / bare / `{}`: WARNING, no demand
- Unknown id: **FATAL**. BuildMaster will not pretend the system binary
  with the same name is “the extra”. If it is not in
  `BUILDMASTER_TOOLS_EXTRA_KNOWN` and `tools/extra/<id>/`, it does not
  exist.

`pkgconfig` (this release) still prefers a working system pkg-config /
pkgconf. Only if that probe fails does it build the bundled tree (the
Windows case, and any runner that shipped a broken one).

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

`WHOLE` on a static component (or a meta) wraps produced archives so the
linker cannot drop unreferenced objects (plugins, statically registered
codecs). Shared / headers / executable: INFO + ignore.

---

## Stripping `.res` members (`STRIPRES`)

Default ON for static MSVC / clang-cl archives. After `RENAME`, `*.res`
members are removed so `/WHOLEARCHIVE` does not duplicate resources.
Other toolchains: silent no-op.

---

## Interprocedural optimization (`IPO`)

Parent `CMAKE_INTERPROCEDURAL_OPTIMIZATION` is a blunt instrument. It
is fine when every leaf is happy under LTO. It is not fine when one
Meson `cc.has_function` probe links a bitcode archive and decides the
symbol does not exist. That is a long evening that looks like a missing
dependency.

`IPO=` is per id. The translator strips foreign LTO tokens and then
puts back only what this profile and this mode asked for.

| Written | Meaning |
|---------|---------|
| *(omit)* | Inherit the parent (`CMAKE_INTERPROCEDURAL_OPTIMIZATION` / `_RELEASE`) and leftover `-flto` / `/GL` tokens |
| `IPO` / `IPO=` / `IPO=on` | Thin LTO on this id |
| `IPO=off` | Strip every IPO token, even if the parent has LTO on |
| `IPO=fat` | Thin LTO plus `-ffat-lto-objects` on gcc/clang **C/CXX** (not on LD). MSVC and clang-cl treat fat as on (`/GL`+`/LTCG`, or `-flto`) |
| anything else | **FATAL** |

Thin tokens: gcc / clang / clang-cl get `-flto` on C, CXX and LD.
MSVC gets `/GL` on C/CXX and `/LTCG` on LD — never `/LTCG` on the
compiler line.

A meta with `IPO=` stamps members that omitted the key (same
destinations as `TOOLCHAIN=`). A member that already wrote `IPO=`
keeps it. Two metas that want different values do not FATAL.

CMake and Meson stages both honour the mode. Meson `-Db_lto=` follows
it (`off` → `false`, `on`/`fat` → `true`, omit → parent).

You do not turn the parent off “just in case”. You write `IPO=off` on
the leaf that cannot probe under LTO, and leave the rest of the graph
alone.

---

## Subcomponent specs

`produced` is `<name>` or `<subdir>/<name>`. Names are canonical
(post-`RENAME`). Libraries resolve under `LIBDIR`. Executables
resolve under `BINDIR`. `buildmaster_link(consumer subdir/name)`
links that library archive only.

---

## Per-component toolchains

`TOOLCHAIN=gcc|clang|clang-cl|msvc`. Nested configure, build and
install use that profile. A meta `TOOLCHAIN` copies onto members that
did not pin one.

The profile owns compilers **and** binutils. `CMAKE_AR` and Meson
`[binaries] ar` / `ld` follow the profile (`msvc` → `lib.exe` +
`link.exe`, `clang-cl` → `llvm-lib` + `lld-link`, `clang` on Linux →
`llvm-ar` + `ld.lld`, `gcc` → binutils `ar` and the driver linker).
A clang-cl parent does not leave `llvm-lib` on an `msvc` leaf.
Paths are absolute before the component toolchain file is written.

Flag dialect is rewritten for that profile before the env runner
refresh: foreign `-I`/`-L`/`-flto`/`/GL` tokens do not leak, then
`IPO=` (or the parent) injects the tokens this profile actually
understands. See
[Interprocedural optimization (`IPO`)](#interprocedural-optimization-ipo).

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
first bootstrap owns `BUILDMASTER_ROOT`, the toolchain dump, and
`BUILDMASTER_LINKS_DIR`. A second tree loads the parent helpers and
returns. Match versions across submodules; a mismatch is WARNING.

Always `add_subdirectory(buildmaster)`. Do not special-case “I am
already inside BM”.

Because helpers and `links/` belong to the trunk, a nested project
that also uses BuildMaster writes into the **same** `links/` folder.
The parent can `buildmaster_link` an id the child already built.
That only works if the child declared those nodes with
`buildmaster_component` / `buildmaster_meta` — not with a private
`target_link_libraries` the parent will never see.

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
| Transitive BM deps across processes | no | no | `links/` |

---

## Self-tests

From the BuildMaster repo:

```sh
rm -rf build/harness && cmake -S .github/tests/harness -B build/harness -G Ninja \
	&& cmake --build build/harness --target run_buildmaster_main
```

That is smoke + negative + consumer (`consumer_nested` and a wiped
`consumer_ci` bindir). The three older targets still exist if you
need them split.

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
