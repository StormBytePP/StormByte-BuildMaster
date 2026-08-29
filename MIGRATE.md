# Migration guide

How to update a **consumer** of StormByte-BuildMaster after a breaking
release.

This file is **not** a changelog.

| File | Role |
|------|------|
| [`CHANGELOG.md`](CHANGELOG.md) | What landed, for whom, in which version |
| [`README.md`](README.md) | Current contract (always `master`) |
| **This file** | How to rewrite caller CMake when a tagged release breaks the public API |

The same steps apply to every tree that `add_subdirectory()`s BuildMaster.

## How to maintain this file

1. When a change is **not** breaking for callers, put it only in
   `CHANGELOG.md`. Do not add a section here.
2. When a change **is** breaking, add a subsection under
   `## Unreleased` **in this file** the same day: old call → new call,
   one table or one snippet. Do not paste the changelog bullet.
3. On release `X.Y.Z`, rename `## Unreleased` to
   `## <previous tag> → X.Y.Z` and start a fresh `## Unreleased`.
4. Keep examples generic (`foo`, `bar`). Do not copy product recipes
   from a consumer.
5. If a helper is removed, say what replaces it even when the
   replacement is an option flag rather than a function.

Baseline: last published tag
[`1.0.1`](https://github.com/StormBytePP/StormByte-BuildMaster/releases/tag/1.0.1)
(`b630c1b`). Target: `master` (forthcoming **2.0.0**).

Public surface on `master` is eighteen `buildmaster_*` commands
(see `.github/tests/expected/public_functions.txt`). Everything else
is `_bm_<craft>_*` and is **not** a supported API.

---

## Unreleased

Nothing yet. After 2.0.0 ships, new breaking notes go here.

---

## 1.0.1 → 2.0.0 (master)

Fully declarative graph. Declaration order no longer matters.
Generated fragments are no longer part of the public API.
The caller does **not** choose CMake vs Meson:
`buildmaster_component` infers the backend from `srcdir`
(`CMakeLists.txt` vs `meson.build`; both or neither is FATAL).

A 1.x `CMakeLists.txt` will not configure. That is the point.

### Removed public commands

| 1.0.1 | master |
|-------|--------|
| `create_cmake_component` | `buildmaster_component` |
| `create_meson_component` | `buildmaster_component` |
| `create_cmake_headers_component` | `buildmaster_component` + mode `headers` |
| `create_meson_headers_component` | `buildmaster_component` + mode `headers` |
| `create_cmake_dependant_component` | `buildmaster_component` + `buildmaster_depend` |
| `create_meson_dependant_component` | `buildmaster_component` + `buildmaster_depend` |
| `create_*_headers_dependant_component` | `buildmaster_component` + `headers` + `buildmaster_depend` |
| `create_bundle_static_libraries` | `buildmaster_repack` |
| `create_cmake_stages` / `create_meson_stages` | Internal (`_bm_tools_*_stages`) |
| First-argument **out-file** on `create_*` / `file_*` / `create_git_*` | Gone. Do **not** `include()` a generated fragment |
| Positional `[indent_level] [toolchain]` | Trailing options string `INDENT=…;TOOLCHAIN=…` |
| Options key `LINK_EXTRA` | `buildmaster_link` (graph node) or `LINK=` (raw system lib) |
| Cache/env `BUILDMASTER_DEBUG` | Ignored. Use `BUILDMASTER_LOGLEVEL` |
| `ensure_build_dir` | Internal. Omit the builddir slot |
| `library_import_hint` / `library_import_static_hint` | Internal |
| `file_checksum_correct` | Internal |
| `file_download` / `file_download_cached` / `file_decompress` | `buildmaster_download{,_cached}` / `buildmaster_decompress` |
| `create_git_reset_file` / `create_git_patch_file` / `create_git_fetch` / `create_git_switch_branch` | `buildmaster_git_{reset,patch,fetch,switch}` |

### Public commands on master

| Command | Role |
|---------|------|
| `buildmaster_component(id title srcdir …)` | Factory. Backend from `srcdir` |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest)` | Link on the component `INTERFACE` + wait if `dest` is a graph node |
| `buildmaster_prerequisite(id target)` | Wait on a host / download / custom target before `<id>_configure` |
| `buildmaster_meta(id title [, options])` | `INTERFACE` collection (no sources, no install) |
| `buildmaster_meta_add(meta member…)` | Membership (allowed before `buildmaster_meta`) |
| `buildmaster_repack(id title output input…)` | Merge static archives (including `BUILDONLY` inputs) |
| `buildmaster_hook_component(id fn alias [CAPTURE …])` | Run `fn` after that id materializes |
| `buildmaster_hook_graph(fn alias [CAPTURE …])` | Run `fn` after the whole graph materializes |
| `buildmaster_message(level text [, indent])` | Only supported log API. Module is always `USER` |
| `buildmaster_download` / `buildmaster_download_cached` / `buildmaster_decompress` | File helpers (no out-var) |
| `buildmaster_git_fetch` / `buildmaster_git_switch` / `buildmaster_git_reset` / `buildmaster_git_patch` | Git helpers (no out-var) |

`buildmaster_link` always records `buildmaster_depend` when `dest` is a
graph node. A spec or on-disk archive is link-only. Duplicate
*explicit* edges are WARNING + no-op. Unresolvable dest at finalize
is FATAL.

### Component signature

**1.0.1**

```cmake
create_cmake_component(
	FOO_CREATE_FILE
	"foo"
	"Foo library"
	"${FOO_SRC}"
	"${FOO_BUILD}"
	"${FOO_OPTIONS}"
	"static"
	"foo"
	"bar_install"   # only on the *dependant* variant
	${PLUGIN_LEVEL}
	# optional toolchain name as last positional
)
include("${FOO_CREATE_FILE}")
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
	"INDENT=${PLUGIN_LEVEL};RENAME;STRIPRES"
)
buildmaster_depend(foo bar)   # bar may be declared later
buildmaster_link(foo bar)     # if foo must actually link bar
```

Build directory is optional. If omitted, BuildMaster assigns
`${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` and creates it
(`file(MAKE_DIRECTORY)`, idempotent). Passing an explicit path is
still accepted; leftover files in that directory are the caller's
problem.

Headers: same factory, mode `headers`. Drop `<produced>` the same way
the old headers wrappers did.

Do **not** capture an out-variable. Do **not** `include()` anything
BuildMaster generated. Materialize runs at the end of
`CMAKE_SOURCE_DIR` via `cmake_language(DEFER)`. An `INTERFACE` stub
named `<id>` exists at registration, so a sibling `ALIAS` /
`target_link_libraries` before DEFER is valid.

Neutral `options` entries the factory understands
(`CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS`, `INCLUDES`,
`DEFINITIONS`) are **private** to the nested compile and **append**
to the parent job / toolchain. They are not `ENV{CFLAGS}`.
Everything else in that list is FATAL. The trailing optstr is
unchanged (`LINK=`, `PC=`, …).

### Options string

One optional trailing argument:

```text
KEY=value;KEY2=value with spaces;PC={VERSION=1.2.3;NAME=foo}
```

- First `=` in each pair splits key from value.
- `;` inside `{…}` is **not** a pair break.
- Keys are case-insensitive, stored uppercase.
- Bare flag (`RENAME`, `WHOLE`, `BUILDONLY`, `STRIPRES`) means `KEY=ON`.
- Unknown keys: **WARNING**, ignored.
- Extra positionals: **FATAL**.

| Key | Default | Notes |
|-----|---------|--------|
| `INDENT` / `INDENT_LEVEL` | `0` | Tabs after the log header |
| `TOOLCHAIN` | inherit | `gcc`, `clang`, `clang-cl`, `msvc` |
| `RENAME` | ON | Canonical archive name after install (or in the build dir if `BUILDONLY`) |
| `WHOLE` | OFF | Whole-archive link of **static** produced archives |
| `BUILDONLY` | OFF | Do not publish into the shared prefix |
| `STRIPRES` | ON | Strip `*.res` from static MSVC / clang-cl archives after `RENAME` |
| `PC={…}` | off unless the group is present | Helper `.pc` for **this** prefix. Bare `PC` / `PC=ON` is **FATAL** |
| `LINK=` / `LINK={…}` | empty | Raw system linker names (`shlwapi`, `ws2_32`) on the id `INTERFACE` |
| `LINKFLAGS=` / `LINKFLAGS={…}` | empty | Raw linker flags. Groups: `WINDOWS`, `LINUX`, `MAC`, `UNIX` (`UNIX` = Linux + macOS). Unknown platform key is **FATAL**. A group that does not apply is skipped at INFO |

`PC` on a **meta** is **FATAL**. `BUILDONLY` + enabled `PC` is **FATAL**.
If the library already installs a `.pc` at the canonical path, do not
set `PC={…}` (collision is **FATAL**).

`LINK=` is **not** a graph node. `buildmaster_link` is.
`LINKFLAGS` ride the same `INTERFACE` as `LINK=` (they propagate to
whoever links that id, including the final `.dll` / `.so`). Put
flags that must **not** leak to the application on a leaf you never
link from the app, or keep them off BuildMaster.

### Graph instead of “dependant” + `POST_BUILD`

| 1.0.1 habit | master |
|-------------|--------|
| 9th argument `"bar_install"` | `buildmaster_depend(foo bar)` |
| `add_dependencies(foo_configure bar_install)` | Same, or `buildmaster_prerequisite` for non-component targets |
| `target_link_libraries(foo INTERFACE bar)` by hand | `buildmaster_link(foo bar)` |
| `add_library(plugins INTERFACE)` + `target_link_libraries(plugins INTERFACE foo)` | `buildmaster_meta(plugins "…")` + `buildmaster_meta_add(plugins foo)` |
| `POST_BUILD` rename / copy `zsd.lib` → `z.lib` | `RENAME` (usually leave default ON) |
| `POST_BUILD` `lib /REMOVE:….res` | `STRIPRES` (default ON; silent on non-MSVC) |
| Parent `/WHOLEARCHIVE:` / `-force_load` / `--whole-archive` loop | `WHOLE` on the component or on the meta you link |
| `create_bundle_static_libraries` + `POST_BUILD` merge | `BUILDONLY` phases + `buildmaster_repack` |
| `file(WRITE) …pc` + copy into `libdir/pkgconfig` | `PC={VERSION=…;NAME=…}` on the **leaf** that owns the archive |
| `LINK_EXTRA=shlwapi` | `LINK=shlwapi` or `LINK={shlwapi;ws2_32}` |
| Hand-written `target_link_options` for `/FORCE:MULTIPLE` | `LINKFLAGS=/FORCE:MULTIPLE` or `LINKFLAGS={WINDOWS={/FORCE:MULTIPLE};UNIX={-Wl,-Bsymbolic}}` |

Host-only libraries (`ws2_32`, Apple frameworks) can live in `LINK=`
when every consumer of that id needs them. Otherwise keep them on the
final `target_link_libraries` of the application.

### File / git helpers

Out-file + `include()` is gone. Bind the operation to a **name** you
later pass to `buildmaster_prerequisite`.

| 1.0.1 | master |
|-------|--------|
| `file_download_cached(OUT url …)` + `include(${OUT})` | `buildmaster_download_cached(<name> <url> [EXPECTED_HASH …] [TITLE …])` then `buildmaster_prerequisite(<id> <name>)` |
| `file_decompress(OUT archive dest …)` + `include` | `buildmaster_decompress(<name> <archive> <dest> [TITLE …])` |
| `create_git_reset_file(OUT id title repo)` + `include` | `buildmaster_git_reset(<id> <title> <repo>)` |
| `create_git_patch_file(OUT id title repo patches)` + `include` | `buildmaster_git_patch(<id> <title> <repo> <patch>)` |
| `create_git_fetch` / `create_git_switch_branch` | `buildmaster_git_fetch` / `buildmaster_git_switch` |

Call `buildmaster_git_*` **before** `buildmaster_component` for that
id. Post-install reset of registered roots is still automatic.
Patch is queued; flush is reset-then-apply once per root.

### Logging

| 1.0.1 | master |
|-------|--------|
| `-DBUILDMASTER_DEBUG=1` or `ENV{BUILDMASTER_DEBUG}` | Ignored |
| `message(STATUS "Setting up Foo")` | `buildmaster_message(STATUS "Setting up Foo" ${PLUGIN_LEVEL})` |
| `buildmaster_message(USER STATUS "…")` | Drop `USER`. Module is always `USER` |
| — | `-DBUILDMASTER_LOGLEVEL=DEBUG` (or `INFO` / `STATUS` / …) |

`BUILDMASTER_VERBOSE` is unchanged (live compiler / linker output).
`WARNING` and `FATAL` are never filtered. CMake `message()` is
forbidden inside BuildMaster except `log.cmake`.

### Layout

BuildMaster and every DSL-driven dependency must be **sibling
directories** under the same parent. The registration `CMakeLists.txt`
is not the nested `srcdir`.

```
thirdparty/
	buildmaster/
	foo/          # registration CMakeLists.txt lives here
		src/      # CMakeLists.txt or meson.build lives here
```

`add_subdirectory(thirdparty/buildmaster)` (or `thirdparty` that
adds it) is enough. Do not `include(…/helpers.cmake)` after that.

### Checklist

- [ ] Delete every `include("${FOO_CREATE_FILE}")` and every out-var
      argument on `create_*` / `file_*` / `create_git_*`.
- [ ] Replace `create_cmake_component` / `create_meson_component` /
      headers wrappers with one `buildmaster_component`.
- [ ] Replace `create_*_dependant_*` with `buildmaster_depend` or
      `buildmaster_link`.
- [ ] Replace `LINK_EXTRA` with `buildmaster_link` or `LINK=`.
- [ ] Replace `create_bundle_static_libraries` with
      `BUILDONLY` + `buildmaster_repack`.
- [ ] Replace `create_git_*` / `file_*` with `buildmaster_git_*` /
      `buildmaster_download*` / `buildmaster_decompress`.
- [ ] Drop `ensure_build_dir` unless you still need the path variable
      for something advanced; the factory creates the directory.
- [ ] Replace `message(STATUS …)` in the consumer with
      `buildmaster_message(STATUS …)` (no module argument).
- [ ] Replace `-DBUILDMASTER_DEBUG=1` with
      `-DBUILDMASTER_LOGLEVEL=DEBUG`.
- [ ] Stop calling `_bm_*`, `create_*_stages`, parse helpers, import
      hints, archiver lookup, checksum, git marker.
- [ ] Confirm `public_functions.txt` still matches what you call.

[Unreleased]: https://github.com/StormBytePP/StormByte-BuildMaster/compare/1.0.1...HEAD
