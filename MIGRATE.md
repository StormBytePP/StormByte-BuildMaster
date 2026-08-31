# Migration guide

How to rewrite a **1.0.1 caller** so it configures on `master`
(forthcoming **2.0.0**).

This file is **not** the contract and **not** the changelog.

| File | Role |
|------|------|
| [`README.md`](README.md) | Current contract (`master`) |
| [`CHANGELOG.md`](CHANGELOG.md) | What landed, and why it broke |
| **This file** | Old call → new call |

Baseline:
[`1.0.1`](https://github.com/StormBytePP/StormByte-BuildMaster/releases/tag/1.0.1)
(`b630c1b`). Target: `master`.

A 1.x `CMakeLists.txt` will not configure. That is the point.

---

## Unreleased

Nothing pending after the notes already folded into **2.0.0** below
(`REQUIRE_TOOL`, death of `BUILDMASTER_INITIALIZE_EXTRA_TOOLS`).
After 2.0.0 ships, new breaking notes go here (`old call → new call`).
Do not paste changelog bullets.

---

## 1.0.1 → 2.0.0 (`master`)

### What actually changed

1.x was **imperative**: pick CMake or Meson, pick a build dir,
generate a fragment, `include()` it, then wire
`add_dependencies(<id>_configure other_install)` by hand.

2.x is **declarative**: register ids, record edges, stop talking.
BuildMaster infers the backend, assigns the build directory,
materializes at the end of `CMAKE_SOURCE_DIR` via
`cmake_language(DEFER)`, and creates an `INTERFACE` stub named
`<id>` at registration so a sibling `ALIAS` is legal before DEFER.

Declaration order does not matter. Generated fragments are not a
public API. `_bm_*` is not a public API.

Public surface on `master` is **ten** commands
(see `.github/tests/expected/public_functions.txt`):

| Command | Role |
|---------|------|
| `buildmaster_component(id title srcdir options mode produced [optstr])` | Factory. Backend from `srcdir`. No builddir |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest)` | Link on the component `INTERFACE` **and** a depend edge when `dest` is a graph node |
| `buildmaster_meta(id title [, optstr])` | `INTERFACE` collection. `REPACK` publishes one merged static archive |
| `buildmaster_meta_add(meta member…)` | Membership (allowed before `buildmaster_meta`) |
| `buildmaster_group(id [title])` | Outline banner. No target, no edge |
| `buildmaster_group_add(group member…)` | Membership. Group must already exist |
| `buildmaster_hook_component(id fn alias [CAPTURE …])` | Run `fn` after that id materializes |
| `buildmaster_hook_graph(fn alias [CAPTURE …])` | Run `fn` after the whole graph materializes |
| `buildmaster_message(level text [, indent])` | Log. Module is always `USER` |

There is no `create_*`. There is no `include()` of a BM fragment.
There is no public git / download / decompress / repack / builddir
helper. Those jobs are optstr on the component (`GIT=`, `FILES=`,
`REPACK` on a **meta**). Extra host tools are optstr too
(`REQUIRE_TOOL=`).

---

### Cheatsheet

| 1.0.1 | `master` |
|-------|----------|
| `create_cmake_component` / `create_meson_component` | `buildmaster_component` (backend from `srcdir`) |
| `create_*_headers_component` | `buildmaster_component` + mode `headers` |
| `create_*_dependant_component` + 9th arg `"bar_install"` | `buildmaster_component` + `buildmaster_depend(foo bar)` |
| `create_*_headers_dependant_component` | mode `headers` + `buildmaster_depend` |
| First-argument **out-file** + `include(${OUT})` | Delete both |
| 4th argument builddir + `ensure_build_dir` | Delete both. BM uses `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` |
| Trailing `[indent] [toolchain]` positionals | `INDENT=…;TOOLCHAIN=…` in the optstr |
| `LINK_EXTRA=shlwapi` | `LINK=shlwapi` or `LINK={shlwapi;ws2_32}` |
| `target_link_libraries(foo INTERFACE bar)` by hand | `buildmaster_link(foo bar)` |
| `add_dependencies(foo_configure bar_install)` | `buildmaster_depend(foo bar)` (or `buildmaster_link` if it must also link) |
| `add_library(plugins INTERFACE)` + manual `target_link_libraries` | `buildmaster_meta` + `buildmaster_meta_add` |
| `create_bundle_static_libraries` / later `buildmaster_repack` | `BUILDONLY` leaves + `buildmaster_meta(id title "REPACK")` + `buildmaster_meta_add` |
| `create_git_reset_file` / `_patch_file` / `_fetch` / `_switch_branch` + `include` | `GIT={FETCH;SWITCH=…;RESET;PATCH=…;TITLE=…}` |
| `file_download` / `file_download_cached` / `file_decompress` + `include` + wait target | `FILES={URL=…;NAME=…;UNPACK;SOURCE;…}` |
| `file(WRITE) …pc` into the prefix | `PC={VERSION=…;NAME=…}` on the **leaf** |
| `POST_BUILD` rename / `lib /REMOVE:*.res` | `RENAME` / `STRIPRES` (both default ON) |
| Parent `--whole-archive` loop | `WHOLE` |
| `set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")` then `add_subdirectory(buildmaster)` | Delete the `set`. Put `REQUIRE_TOOL=pkgconfig` on the component or meta that **needs the binary** |
| `BUILDMASTER_DEBUG` | Ignored. `BUILDMASTER_LOGLEVEL` |
| `buildmaster_message(USER STATUS "…")` | Drop `USER` |
| `create_cmake_stages` / `create_meson_stages` | Internal |
| `library_import_hint` | Internal |

`buildmaster_prerequisite` does **not** exist on `master`. A download
is no longer a host target you wait on; it is `FILES=` and it always
runs before that id’s nested configure.

---

### Extra tools (replaces `BUILDMASTER_INITIALIZE_EXTRA_TOOLS`)

**2.x draft / early 2.0 tree**

```cmake
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")
add_subdirectory(thirdparty/buildmaster)
```

That variable is **gone**. Setting it does nothing useful. Extra
tools are not started with the tools tree.

**master**

```cmake
add_subdirectory(thirdparty/buildmaster)

buildmaster_component(
	ffmpeg
	"FFmpeg"
	"${FFMPEG_SRC}"
	""
	static
	avcodec
	"REQUIRE_TOOL=pkgconfig;PC={VERSION=7.0;NAME=libavcodec}"
)
```

Or several ids:

```cmake
"REQUIRE_TOOL={pkgconfig}"
```

Rules:

- The token is `pkgconfig` (folder `tools/extra/pkgconfig`), not
  `pkgconf`.
- Empty `REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}` is
  WARNING and ignored.
- An id that is not in `BUILDMASTER_TOOLS_EXTRA_KNOWN` is FATAL.
  BM will not silently use a same-named system binary.
- `PC={…}` only **writes** a helper `.pc`. It does **not** demand
  `pkgconfig`. The leaf that *reads* `.pc` files is the one that
  must say `REQUIRE_TOOL=pkgconfig`.
- `pkgconfig` still probes the system first and builds the bundled
  tree only when that probe fails (Windows, broken PATH).
- Allowed on `buildmaster_component` and `buildmaster_meta`.
- `cmake` / `meson` / `git` / `file` / `ninja` are **not** extras.
  Do not put them in `REQUIRE_TOOL` (FATAL).

`ninja` and the archiver always start at bootstrap. Everything else
is on demand.

---

### One component, before and after

**1.0.1**

```cmake
ensure_build_dir(FOO_BUILD)
create_cmake_component(
	FOO_CREATE_FILE
	foo
	"Foo library"
	"${FOO_SRC}"
	"${FOO_BUILD}"
	"${FOO_OPTIONS}"
	static
	foo
	${PLUGIN_LEVEL}
)
include("${FOO_CREATE_FILE}")
add_dependencies(foo_configure bar_install)
target_link_libraries(foo INTERFACE bar)
```

**master**

```cmake
buildmaster_component(
	foo
	"Foo library"
	"${FOO_SRC}"
	"${FOO_OPTIONS}"
	static
	foo
	"INDENT=${PLUGIN_LEVEL}"
)
buildmaster_depend(foo bar)   # bar may be declared later
buildmaster_link(foo bar)     # if foo must actually link bar
```

Passing a path where 1.x put the builddir is FATAL (wrong arity).
Do not capture an out-variable. Do not `include()` anything
BuildMaster generated.

Headers: same factory, mode `headers`. Drop `<produced>` the same
way the old headers wrappers did.

Neutral entries in the `options` list (`CFLAGS`, `CXXFLAGS`,
`CPPFLAGS`, `LDFLAGS`, `INCLUDES`, `DEFINITIONS`) are **private**
to the nested compile and **append** to the parent job / toolchain.
They are not `ENV{CFLAGS}`.

`CMakeLists.txt` **and** `meson.build` in `srcdir` is FATAL.
Neither marker + mode `headers` → backend `none` (headers island).
Neither marker + any other mode is FATAL.

---

### Options string

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
| `INDENT` / `INDENT_LEVEL` | `0` | WARNING + ignored. Use `buildmaster_group` |
| `TOOLCHAIN` | inherit | `gcc`, `clang`, `clang-cl`, `msvc` |
| `RENAME` | ON | Canonical archive name after install (or in the build dir if `BUILDONLY`) |
| `WHOLE` | OFF | Whole-archive link of **static** produced archives |
| `BUILDONLY` | OFF | Do not publish into the shared prefix |
| `STRIPRES` | ON | Strip `*.res` from static MSVC / clang-cl archives after `RENAME` |
| `REPACK` | OFF | **Meta only.** Merge every produced static of the members. Stem = meta id |
| `PC={…}` | off unless the group is present | Helper `.pc` for **this** prefix. Bare `PC` / `PC=ON` is FATAL. Does **not** start pkg-config |
| `LINK=` / `LINK={…}` | empty | Raw system linker **names** on the id `INTERFACE` |
| `LINKFLAGS=` / `LINKFLAGS={…}` | empty | Raw linker **flags**, nested link only. Groups: `WINDOWS`, `LINUX`, `MAC`, `UNIX` |
| `GIT={…}` | off | Srcdir git. Empty group is WARNING. Meta + any op is FATAL |
| `FILES={…}` | off | Download / unpack. Meta + any group is FATAL |
| `REQUIRE_TOOL=` / `REQUIRE_TOOL={…}` | off | Demand an extra (`pkgconfig`). Empty group is WARNING. Unknown id is FATAL |

`PC` on a meta is FATAL. `BUILDONLY` + enabled `PC` is FATAL.
`REPACK` on a component is FATAL. `BUILDONLY` + shared as a
`REPACK` member is FATAL (the `.so` / `.dll` is not in the prefix
and the builddir is not public). Shared members that *do* install
stay on the meta `INTERFACE` (WARNING: they are not folded into
the pack).

`LINK=` is **not** a graph node. `buildmaster_link` is.

`LINKFLAGS` is folded into that id’s nested OPTIONS
(`CMAKE_EXE/SHARED/MODULE_LINKER_FLAGS` or Meson `c_link_args` /
`cpp_link_args`). It is **not** `target_link_options` on the
`INTERFACE`. A consumer of this id does not inherit the flags.
Meta / headers: WARNING + ignore.

---

### Graph

`buildmaster_link` always records `buildmaster_depend` when `dest`
is a graph node. A spec (`name` / `subdir/name`) or an on-disk
archive is link-only. Duplicate *explicit* edges are WARNING +
no-op. Unresolvable dest at finalize is FATAL.

Components without edges still configure during parent configure.
Components with edges configure at build time under
`<id>_configure`.

A hook is **not** an edge and does **not** flip the component to
deferred. If the nested project must see a hook artifact at
*configure* time, say so with `buildmaster_depend`.

```cmake
buildmaster_meta(plugins "plugin pack")
buildmaster_meta_add(plugins opus vorbis)
buildmaster_link(engine plugins)
```

`buildmaster_meta_add` may run before `buildmaster_meta`.

Meta `TOOLCHAIN=<profile>` copies onto members and onto empty
dests. An explicit child `TOOLCHAIN` wins.

---

### Files (replaces `file_*` + wait target)

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

- Always cached under `BUILDMASTER_DOWNLOADSDIR` (`FORCE` refetches).
- Unpack lives under `${BUILDMASTER_BINDIR}/files/<NAME>/`, **before**
  nested configure (eager ids included).
- `SOURCE` (at most one group, requires `UNPACK`) **is** the srcdir.
  The positional path is ignored by design (WARNING).
- Other unpacked groups inject a private `-I` on that id only
  (same rule as a headers island).
- `GIT={…}` + `SOURCE` is FATAL.
- Several `FILES={…}` groups are allowed; write them as separate
  optstr groups.

Do not call `buildmaster_download` / `buildmaster_decompress`.
Those names are not public on `master`.

---

### Git (replaces `create_git_*` + `include`)

```cmake
buildmaster_component(
	foo
	"Foo library"
	"${FOO_SRC}"
	""
	static
	foo
	"GIT={RESET;PATCH=${CMAKE_CURRENT_SOURCE_DIR}/0001-cmake4.patch;TITLE=Foo}"
)
```

Flush order is fixed: **FETCH → SWITCH → RESET → PATCH**.
`PATCH=` files keep declaration order; they are not sorted.
Relative `PATCH=` is from `CMAKE_CURRENT_SOURCE_DIR`.
`FETCH` / `RESET` are inner flags, not `KEY=value`.
Empty `GIT` / `GIT={}` is WARNING.
Post-install `reset --hard` + `clean -fd` runs only when a PATCH
was queued. RESET at the start of the group is the usual way to
survive a half-configured tree; it is not mandatory.

Meta + any git op is FATAL (a meta has no srcdir).

---

### Repack (replaces `create_bundle_static_libraries`)

**1.0.1**

```cmake
create_bundle_static_libraries(FOO_BUNDLE "foo" "merged" "a;b")
include("${FOO_BUNDLE}")
```

**master**

```cmake
buildmaster_component(enc-8  "enc 8"  "${ENC8_SRC}"  "" static enc "BUILDONLY")
buildmaster_component(enc-10 "enc 10" "${ENC10_SRC}" "" static enc "BUILDONLY")
buildmaster_meta(enc "encoder" "REPACK")
buildmaster_meta_add(enc enc-8 enc-10)
buildmaster_link(engine enc)
```

The meta id **is** the output stem. The members **are** the inputs.
Wait edge is `_install` for a publishing leaf and `_build` for
`BUILDONLY`.

---

### Logging

| 1.0.1 | `master` |
|-------|----------|
| `-DBUILDMASTER_DEBUG=1` / `ENV{BUILDMASTER_DEBUG}` | Ignored |
| `message(STATUS "Setting up Foo")` | `buildmaster_message(STATUS "Setting up Foo" ${PLUGIN_LEVEL})` |
| `buildmaster_message(USER STATUS "…")` | Drop `USER` |
| — | `-DBUILDMASTER_LOGLEVEL=DEBUG` |

`BUILDMASTER_VERBOSE` is nested compile `--verbose` / `-v` plus the
configure report. It is not a log level.
`WARNING` and `FATAL` are never filtered.

---

### Layout

BuildMaster and every DSL-driven dependency must be **sibling
directories** under the same parent. The registration
`CMakeLists.txt` is not the nested `srcdir`.

```
thirdparty/
	buildmaster/
	foo/            # registration CMakeLists.txt lives here
		src/        # CMakeLists.txt or meson.build lives here
```

`add_subdirectory(thirdparty/buildmaster)` (or a `thirdparty`
that adds it) is enough. Do not `include(…/helpers.cmake)` after
that. Do not set `BUILDMASTER_INITIALIZE_EXTRA_TOOLS` first.

---

### Checklist

- [ ] Delete every `include("${FOO_CREATE_FILE}")` and every out-var
      on `create_*` / `file_*` / `create_git_*`.
- [ ] Replace every `create_{cmake,meson}[_headers][_dependant]_component`
      with one `buildmaster_component`.
- [ ] Delete the builddir argument and every `ensure_build_dir` /
      `_bm_path_builddir` call.
- [ ] Replace the 9th-arg `"bar_install"` / hand
      `add_dependencies(*_configure *_install)` with
      `buildmaster_depend` or `buildmaster_link`.
- [ ] Delete `buildmaster_prerequisite` if a 2.x draft still has it.
      Downloads are `FILES=`.
- [ ] Replace `LINK_EXTRA` with `buildmaster_link` (graph node) or
      `LINK=` (system lib name).
- [ ] Move `/FORCE:MULTIPLE` / `-Wl,-Bsymbolic` to `LINKFLAGS=`
      on the **leaf that links**, not on the final consumer.
- [ ] Replace `create_bundle_static_libraries` /
      `buildmaster_repack` with `BUILDONLY` +
      `buildmaster_meta(… "REPACK")` + `buildmaster_meta_add`.
- [ ] Replace `create_git_*` + `include` with `GIT={…}`.
- [ ] Replace `file_download*` / `file_decompress` + wait target
      with `FILES={…}`.
- [ ] Delete `set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS …)`.
      Put `REQUIRE_TOOL=pkgconfig` on the id that reads `.pc`
      files (not on every `PC=` writer).
- [ ] Drop `USER` from `buildmaster_message`.
- [ ] Stop reading `BUILDMASTER_DEBUG`; set `BUILDMASTER_LOGLEVEL`.
- [ ] Do not call `_bm_*` from a consumer. If configure dies with
      `Unknown CMake command "create_cmake_component"`, the port
      is incomplete — that is expected.

---

### How to maintain this file

1. A change that is **not** breaking for callers lives only in
   `CHANGELOG.md`.
2. A change that **is** breaking gets a subsection under
   `## Unreleased` the same day: old call → new call.
3. On release `X.Y.Z`, rename `## Unreleased` to
   `## <previous tag> → X.Y.Z` and start a fresh `## Unreleased`.
4. Keep examples generic (`foo`, `bar`). Do not paste a consumer
   recipe.
