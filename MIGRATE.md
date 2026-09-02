```markdown
# Migration guide

Old public call → current public call.

This file is **not** the contract and **not** the changelog.
It exists so a caller can port without reading internals.

| File | Role |
|------|------|
| [README.md](README.md) | Current contract |
| [CHANGELOG.md](CHANGELOG.md) | What landed, and why it broke |
| [public_functions.md](public_functions.md) | The ten public names |
| **This file** | Old call → new call |

A previous major’s `CMakeLists.txt` will not configure on the next
major. That is the point.

Versioned sections below keep the *from* and *to* tags in the
heading only. Do not put those tags in this preamble.

---

## [Unreleased]

Empty while every caller-breaking note already lives under a
versioned heading below. After a tagged release, new *caller-breaking*
notes (`old call → new call`) land here until the next tag.
Do not paste changelog bullets.

[Unreleased]: https://github.com/StormBytePP/StormByte-BuildMaster/compare/2.0.0...HEAD

---

## [1.0.1 → 2.0.0]

### What changed

1.x was imperative: pick CMake or Meson, pick a build dir,
generate a fragment, `include()` it, wire
`add_dependencies(<id>_configure other_install)` by hand.

2.0.0 is declarative: register ids, record edges, stop talking.
Backend from `srcdir`. Build dir is
`${CMAKE_CURRENT_BINARY_DIR}/bm/<id>`. Materialize at the end of
`CMAKE_SOURCE_DIR`. `INTERFACE` stub `<id>` exists at registration.

`_bm_*` is not a public API. Generated fragments are not a public API.

Public surface: **ten** commands
(`.github/tests/expected/public_functions.txt`).
Details and examples: [README.md](README.md).

| Command | Role |
|---------|------|
| `buildmaster_component(id title srcdir options mode produced [optstr])` | Factory. Mode `static` / `shared` / `headers` / `executable`. No builddir |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest [dest…])` | `INTERFACE` link + depend when `dest` is a graph node |
| `buildmaster_meta(id title [, optstr])` | `INTERFACE` collection. `REPACK` merges static members |
| `buildmaster_meta_add(meta member…)` | Membership (allowed before `buildmaster_meta`) |
| `buildmaster_group(id [title])` | Outline only |
| `buildmaster_group_add(group member…)` | Outline membership |
| `buildmaster_hook_component(id fn alias [CAPTURE …])` | After that id materializes |
| `buildmaster_hook_graph(fn alias [CAPTURE …])` | After the whole graph materializes |
| `buildmaster_message(level text [, indent])` | Log. Module always `USER` |

---

### Cheatsheet

| 1.0.1 | 2.0.0 |
|-------|--------|
| `create_cmake_component` / `create_meson_component` | `buildmaster_component` |
| `create_*_headers_component` | same factory, mode `headers` |
| `create_*_dependant_component` + 9th arg `"bar_install"` | `buildmaster_component` + `buildmaster_depend(foo bar)` |
| First-argument out-file + `include(${OUT})` | Delete both |
| 4th argument builddir + `ensure_build_dir` | Delete both |
| Trailing `[indent] [toolchain]` positionals | `TOOLCHAIN=…` in the optstr. `INDENT=` is WARNING + ignore (`buildmaster_group`) |
| `LINK_EXTRA=shlwapi` | `LINK=shlwapi` or `buildmaster_link` if it is a BM id |
| `target_link_libraries(foo INTERFACE bar)` by hand | `buildmaster_link(foo bar)` |
| `add_dependencies(foo_configure bar_install)` | `buildmaster_depend(foo bar)` |
| `add_library(plugins INTERFACE)` + manual links | `buildmaster_meta` + `buildmaster_meta_add` |
| `create_bundle_static_libraries` / `buildmaster_repack` | `NOINSTALL` leaves + `buildmaster_meta(id title "REPACK")` + `buildmaster_meta_add`, or `REPACK` on a **static** component |
| `create_git_*` + `include` | `GIT={FETCH;SWITCH=…;RESET;PATCH=…}` |
| `file_download*` / `file_decompress` + wait target | `FILES={URL=…;NAME=…;UNPACK;SOURCE;…}` |
| `file(WRITE) …pc` | `PC={VERSION=…;NAME=…}` on the leaf |
| `POST_BUILD` rename / `lib /REMOVE:*.res` | `RENAME` / `STRIPRES` (default ON) |
| Parent `--whole-archive` loop | `WHOLE` |
| `set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")` | Delete. `REQUIRE_TOOL=pkgconfig` on the id that **reads** `.pc` |
| `BUILDMASTER_DEBUG` | Ignored. `BUILDMASTER_LOGLEVEL` |
| `buildmaster_message(USER STATUS "…")` | Drop `USER` |
| `create_cmake_stages` / `library_import_hint` | Internal |
| `buildmaster_prerequisite` | Does not exist. Downloads are `FILES=` |

---

### One component

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

**2.0.0**

```cmake
buildmaster_component(
	foo
	"Foo library"
	"${FOO_SRC}"
	"${FOO_OPTIONS}"
	static
	foo
)
buildmaster_depend(foo bar)
buildmaster_link(foo bar)
```

A path where 1.x put the builddir is FATAL (wrong arity).
Do not `include()` anything BuildMaster generated.

`CMakeLists.txt` **and** `meson.build` in `srcdir`: FATAL unless
`BACKEND=`. Neither marker + mode `headers` → backend `none`.
Neither marker + any other mode: FATAL unless `NOINSTALL`.

---

### Extra tools

**2.x draft**

```cmake
set(BUILDMASTER_INITIALIZE_EXTRA_TOOLS "pkgconf")
add_subdirectory(thirdparty/buildmaster)
```

That variable is gone.

**2.0.0**

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

- Token is `pkgconfig`, not `pkgconf`.
- Empty `REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}`: WARNING.
- Unknown id: FATAL. No silent PATH fallback.
- `PC={…}` writes a helper `.pc`. It does **not** start pkg-config.
- `cmake` / `meson` / `git` / `file` / `ninja` are not extras (FATAL
  inside `REQUIRE_TOOL`).
- Bootstrap tool: **`ninja` only**. Archiver is the `TOOLCHAIN=`
  profile (`CMAKE_AR`, Meson `[binaries] ar` / `ld`).

---

### Options string

One trailing argument: `KEY=value;PC={VERSION=1.2.3;NAME=foo}`.

- First `=` splits. `;` inside `{…}` is not a pair break.
- Bare flag (`RENAME`, `WHOLE`, `NOINSTALL`, `STRIPRES`, `REPACK`,
  `REQUIRE_TOOL`) means ON.
- `BUILDONLY` is accepted only so the parser can FATAL
  (`use NOINSTALL`).
- Unknown keys: WARNING. Extra positionals: FATAL.

| Key | 2.0.0 |
|-----|--------|
| `TOOLCHAIN` | `gcc` / `clang` / `clang-cl` / `msvc` |
| `RENAME` | ON. Canonical name after oficios (prefix or BUILDDIR) |
| `NOINSTALL` | Flag. No prefix publish. Oficios still run on `_install` |
| `REPACK` | Meta **or** static component. Members = inputs. Stem = publisher id |
| `WHOLE` / `STRIPRES` / `PC=` / `LINK=` / `LINKFLAGS=` / `GIT=` / `FILES=` / `REQUIRE_TOOL=` / `ALIAS=` / `BACKEND=` / `SOURCE=` | [README.md](README.md) |
| `INDENT=` | WARNING + ignore. Use `buildmaster_group` |

`NOINSTALL` + enabled `PC=`: FATAL.
`REPACK` + `NOINSTALL` on the **same** id: FATAL.
`REPACK` on headers / executable: FATAL.
`buildmaster_link` to a `NOINSTALL` dest: FATAL (use `depend`, or
publish through REPACK).

`LINKFLAGS` is nested OPTIONS only. Not INTERFACE. Meta / headers:
WARNING + ignore.

---

### Repack

**1.0.1**

```cmake
create_bundle_static_libraries(FOO_BUNDLE "foo" "merged" "a;b")
include("${FOO_BUNDLE}")
```

**2.0.0**

```cmake
buildmaster_component(enc-8  "enc 8"  "${ENC8_SRC}"  "" static enc "NOINSTALL")
buildmaster_component(enc-10 "enc 10" "${ENC10_SRC}" "" static enc "NOINSTALL")
buildmaster_meta(enc "encoder" "REPACK")
buildmaster_meta_add(enc enc-8 enc-10)
buildmaster_link(engine enc)
```

Wait edge is `<id>_install` for every static member, including
`NOINSTALL` (`cmake --install` is skipped; `RENAME` still runs on
the BUILDDIR so merge sees `enc.lib`, not `enc-static.lib`).

---

### Files

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

Cache: `BUILDMASTER_DOWNLOADSDIR`. Unpack before nested configure.
FILES `SOURCE` *is* the srcdir (positional path WARNING).
`GIT={…}` + FILES `SOURCE`: FATAL.
No public `buildmaster_download` / `buildmaster_decompress`.

---

### Git

```cmake
"GIT={RESET;PATCH=${CMAKE_CURRENT_SOURCE_DIR}/0001-cmake4.patch;TITLE=Foo}"
```

Order: FETCH → SWITCH → RESET → PATCH.
Post-install reset only if a PATCH was queued, only in `GIT ROOT=`.
Meta + any git op: FATAL.

---

### Logging

| 1.0.1 | 2.0.0 |
|-------|--------|
| `BUILDMASTER_DEBUG` | Ignored |
| `buildmaster_message(USER STATUS "…")` | Drop `USER` |
| — | `BUILDMASTER_LOGLEVEL` / `BUILDMASTER_LOG_NOCOLOR` |

`BUILDMASTER_VERBOSE` is nested `-v` plus the configure report.
Not a log level.

---

### Layout

```
thirdparty/
	buildmaster/
	foo/            # registration CMakeLists.txt
		src/        # CMakeLists.txt or meson.build
```

`add_subdirectory(thirdparty/buildmaster)` is enough.
Do not `include(helpers.cmake)`.

---

### Checklist

- [ ] Delete every `include("${FOO_CREATE_FILE}")` and every out-var
      on `create_*` / `file_*` / `create_git_*`.
- [ ] One `buildmaster_component` per old `create_*`.
- [ ] Delete builddir / `ensure_build_dir`.
- [ ] `buildmaster_depend` / `buildmaster_link` instead of
      `add_dependencies(*_configure *_install)`.
- [ ] Downloads are `FILES=`. No `buildmaster_prerequisite`.
- [ ] `LINK_EXTRA` → `buildmaster_link` or `LINK=`.
- [ ] Leaf `LINKFLAGS=`, not the final consumer.
- [ ] Bundle → `NOINSTALL` + meta `REPACK` (or `REPACK` on a static
      publisher). Not `BUILDONLY`.
- [ ] `create_git_*` → `GIT={…}`.
- [ ] Delete `BUILDMASTER_INITIALIZE_EXTRA_TOOLS`.
      `REQUIRE_TOOL=pkgconfig` on the reader of `.pc` files.
- [ ] Drop `USER` on `buildmaster_message`.
- [ ] `BUILDMASTER_LOGLEVEL`, not `BUILDMASTER_DEBUG`.
- [ ] Do not call `_bm_*`. `Unknown CMake command
      "create_cmake_component"` means the port is incomplete.

---

[1.0.1 → 2.0.0]: https://github.com/StormBytePP/StormByte-BuildMaster/compare/1.0.1...HEAD

### How to maintain this file

1. Not breaking for callers → `CHANGELOG.md` only.
2. Breaking → subsection under `## [Unreleased]`: old call → new call.
3. On release `X.Y.Z`, rename Unreleased to
   `## [<previous> → X.Y.Z]` and start a fresh Unreleased.
4. Examples stay generic (`foo`, `bar`). No consumer recipe.


