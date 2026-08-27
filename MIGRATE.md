# Migration guide

How to update a **consumer** of StormByte-BuildMaster after a breaking
release.

This file is **not** a changelog.

| File | Role |
|------|------|
| [`CHANGELOG.md`](CHANGELOG.md) | What landed, for whom, in which version |
| [`README.md`](README.md) | Current contract (always `master`) |
| **This file** | How to rewrite caller CMake when a tagged release breaks the public API |

There is one consumer today (StormByte-Multimedia). The same steps apply
to any later tree.

## How to maintain this file

1. When a change is **not** breaking for callers, put it only in
   `CHANGELOG.md`. Do not add a section here.
2. When a change **is** breaking, add a subsection under
   `## Unreleased` **in this file** the same day: old call → new call,
   one table or one snippet. Do not paste the changelog bullet.
3. On release `X.Y.Z`, rename `## Unreleased` to
   `## <previous tag> → X.Y.Z` and start a fresh `## Unreleased`.
4. Keep examples generic (`foo`, `bar`). Do not copy product recipes
   (codec names, license gates) from a consumer.
5. If a helper is removed (`create_bundle_static_libraries`,
   `rename_msvc_lib.cmake` in the consumer, …), say what replaces it
   even when the replacement is an option flag rather than a function.

Baseline for the current text: last published tag
[`1.0.1`](https://github.com/StormBytePP/StormByte-BuildMaster/releases/tag/1.0.1)
(`b630c1b`). Target: `master` (forthcoming **2.0.0**).

---

## Unreleased

Nothing yet. After 2.0.0 ships, new breaking notes go here.

---

## 1.0.1 → 2.0.0 (master)

Fully declarative graph. Declaration order no longer matters.
Generated fragments are no longer part of the public API.

### Removed public commands

| 1.0.1 | 2.0 |
|-------|-----|
| `create_cmake_dependant_component` | `create_cmake_component` + `component_dependency` |
| `create_meson_dependant_component` | `create_meson_component` + `component_dependency` |
| `create_cmake_headers_dependant_component` | `create_cmake_headers_component` + `component_dependency` |
| `create_meson_headers_dependant_component` | `create_meson_headers_component` + `component_dependency` |
| `create_bundle_static_libraries` | `component_repack` |
| First-argument **out-file** on `create_*` / `file_*` / `create_git_*` | Gone. Do **not** `include()` a generated fragment |
| Positional `[indent_level] [toolchain]` | Trailing options string `INDENT=…;TOOLCHAIN=…` |
| Options key `LINK_EXTRA` | `component_link` |
| Cache/env `BUILDMASTER_DEBUG` | Ignored. Use `BUILDMASTER_LOGLEVEL` |
| Public use of `create_*_stages` | Internal only |

`create_cmake_component`, `create_meson_component`, and the headers
variants remain. Their **signature** changed.

### New public commands

| Command | Role |
|---------|------|
| `component_dependency(source, dest)` | Order-only edge |
| `component_link(source, dest)` | Link on the component `INTERFACE` + wait if `dest` is a graph node |
| `component_prerequisite(id, target)` | Wait on a host / `file_*` / custom target before `<id>_configure` |
| `create_meta_component(id, title [, options])` | `INTERFACE` collection (no sources, no install) |
| `meta_component_add(meta, member…)` | Membership (allowed before `create_meta_component`) |
| `component_repack(id, title, output, input…)` | Merge static archives (including `BUILDONLY` inputs) |
| `buildmaster_message(module, level, text [, indent])` | Only supported log API |

### `create_*` signature

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

**2.0**

```cmake
create_cmake_component(
	foo
	"Foo library"
	"${FOO_SRC}"
	"${FOO_BUILD}"
	"${FOO_OPTIONS}"
	static
	foo
	"INDENT=${PLUGIN_LEVEL};RENAME;STRIPRES"
)
component_dependency(foo bar)   # bar may be declared later
component_link(foo bar)         # if foo must actually link bar
```

Same shape for `create_meson_component`.
Headers variants drop `<build_dir>`, `<mode>`, and `<produced>`.

Do **not** capture an out-variable. Do **not** `include()` anything
BuildMaster generated. Materialize runs at the end of
`CMAKE_SOURCE_DIR` via `cmake_language(DEFER)`.

### Options string

One optional trailing argument:

```text
KEY=value;KEY2=value with spaces;PC={VERSION=1.2.3;NAME=foo}
```

- First `=` in each pair splits key from value.
- `;` inside `PC={…}` is **not** a pair break.
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
| `PC={…}` | off unless the group is present | Helper `.pc` for **this** prefix. See README. Bare `PC` / `PC=ON` is **FATAL**. |

`PC` on a **meta** is **FATAL**. `BUILDONLY` + enabled `PC` is **FATAL**.
If the library already installs a `.pc` at the canonical path, do not
set `PC={…}` (collision is **FATAL**).

### Graph instead of “dependant” + `POST_BUILD`

| 1.0.1 habit | 2.0 |
|-------------|-----|
| 9th argument `"bar_install"` | `component_dependency(foo bar)` |
| `add_dependencies(foo_configure bar_install)` | Same, or `component_prerequisite` for non-component targets |
| `target_link_libraries(foo_component INTERFACE bar)` by hand | `component_link(foo bar)` |
| `add_library(plugins INTERFACE)` + `target_link_libraries(plugins INTERFACE foo)` | `create_meta_component(plugins "…")` + `meta_component_add(plugins foo)` |
| `POST_BUILD` rename / copy `zsd.lib` → `z.lib` | `RENAME` (usually leave default ON) |
| `POST_BUILD` `lib /REMOVE:….res` | `STRIPRES` (default ON; silent on non-MSVC) |
| Parent `/WHOLEARCHIVE:` / `-force_load` / `--whole-archive` loop | `WHOLE` on the component or on the meta you link |
| `create_bundle_static_libraries` + `POST_BUILD` merge | `BUILDONLY` phases + `component_repack` |
| `file(WRITE) …pc` + copy into `libdir/pkgconfig` | `PC={VERSION=…;NAME=…}` on the **leaf** that owns the archive |

Host-only libraries (`ws2_32`, Apple frameworks) are **not** graph
nodes. Keep them on the final `target_link_libraries` of the
application.

### File / git helpers

Out-file + `include()` is gone. Bind the operation to a **component
id** (or a name you later pass to `component_prerequisite`).

| 1.0.1 | 2.0 |
|-------|-----|
| `file_download_cached(OUT url …)` + `include(${OUT})` | `file_download_cached(<name> <url> [EXPECTED_HASH …] [TITLE …])` then `component_prerequisite(<id> <name>)` |
| `file_decompress(OUT archive dest …)` + `include` | `file_decompress(<name> <archive> <dest> [TITLE …])` |
| `create_git_reset_file(OUT id title repo)` + `include` | `create_git_reset_file(<id> <title> <repo>)` |
| `create_git_patch_file(OUT id title repo patches)` + `include` | `create_git_patch_file(<id> <title> <repo> <patch>)` |
| `create_git_fetch` / `create_git_switch_branch` | Same drop of `OUT` + `include` |

Call `create_git_*` **before** `create_*_component` for that id.
Post-install reset of registered roots is still automatic.

### Logging

| 1.0.1 | 2.0 |
|-------|-----|
| `-DBUILDMASTER_DEBUG=1` or `ENV{BUILDMASTER_DEBUG}` | Ignored |
| `message(STATUS "Setting up Foo")` | `buildmaster_message(USER STATUS "Setting up Foo" ${PLUGIN_LEVEL})` |
| — | `-DBUILDMASTER_LOGLEVEL=DEBUG` (or `INFO` / `STATUS` / …) |

`BUILDMASTER_VERBOSE` is unchanged (Ninja / compiler command lines).
It is independent of `BUILDMASTER_LOGLEVEL`.

`USER` is the module name reserved for the consumer so headers line
up with BuildMaster’s own output.

### Minimal rewrite (leaf + dependency)

```cmake
# 1.0.1
create_cmake_dependant_component(
	PNG_CREATE
	png "libpng" "${PNG_SRC}" "${PNG_BUILD}"
	"${PNG_OPTIONS}" "${TYPE}" png
	"zlib_install"
	${PLUGIN_LEVEL}
)
include("${PNG_CREATE}")

# 2.0
create_cmake_component(
	png "libpng" "${PNG_SRC}" "${PNG_BUILD}"
	"${PNG_OPTIONS}" ${TYPE} png
	"INDENT=${PLUGIN_LEVEL}"
)
component_dependency(png zlib)
component_link(png zlib)
```

### Collection that the parent whole-archives

```cmake
# 1.0.1
add_library(ffmpeg-plugins INTERFACE)
add_dependencies(ffmpeg-plugins png_install opus_install)
target_link_libraries(ffmpeg-plugins INTERFACE png opus)
# parent then walks INTERFACE_LINK_LIBRARIES and emits /WHOLEARCHIVE:

# 2.0
create_meta_component(ffmpeg-plugins "FFmpeg plugins" "WHOLE")
meta_component_add(ffmpeg-plugins png opus)
# parent:
target_link_libraries(MyApp PRIVATE ffmpeg-plugins)
```

Membership does not build anything. Something must **consume** the
meta (`component_link`, `component_dependency`, or host
`target_link_libraries` / `DEPENDS`). Unused metas warn as orphans.

### Multi-phase static (the x265 shape)

```cmake
create_cmake_component(foo12 "Foo 12-bit" … static foo12 "BUILDONLY")
create_cmake_component(foo10 "Foo 10-bit" … static foo10 "BUILDONLY")
create_cmake_component(foo8  "Foo 8-bit"  … static foo8)

component_dependency(foo8 foo12)
component_dependency(foo8 foo10)

component_repack(
	foo-merged "Foo merged"
	foo
	foo8 foo10 foo12
)
```

Do not `component_link` a normal component to a `BUILDONLY` id
(**FATAL**). Feed `BUILDONLY` archives only into `component_repack`
(or another `BUILDONLY`).

### Checklist

- [ ] Delete every `include("${…_CREATE_FILE}")` / `include("${…_RESET}")`.
- [ ] Drop the first out-variable argument on `create_*`, `file_*`, `create_git_*`.
- [ ] Replace `create_*_dependant_*` with `create_*` + `component_dependency`.
- [ ] Move indent / toolchain into the trailing options string.
- [ ] Replace `LINK_EXTRA` and hand-rolled `target_link_libraries` on
      imported component targets with `component_link`.
- [ ] Replace consumer `rename_*.cmake` / strip-`.res` scripts with
      `RENAME` / `STRIPRES` (defaults are already ON).
- [ ] Replace parent whole-archive loops with `WHOLE` on the meta or leaf.
- [ ] Replace `create_bundle_static_libraries` with `component_repack`.
- [ ] Replace hand-written helper `.pc` files with `PC={VERSION=…}`
      only when the project does **not** already install one.
- [ ] Replace `INTERFACE` aggregator libraries with
      `create_meta_component` + `meta_component_add`.
- [ ] Replace `BUILDMASTER_DEBUG` with `BUILDMASTER_LOGLEVEL`.
- [ ] Prefer `buildmaster_message(USER …)` over `message()`.
- [ ] Keep license gates, Meson `-Dlibfoo=enabled`, Apple frameworks,
      and `ws2_32` in the **consumer**. Those are not BuildMaster.

### What did not break

- Shared install prefix (`BUILDMASTER_INSTALL_DIR` / `LIBDIR` /
  `INCLUDEDIR`) and env / pkg-config propagation into nested Meson.
- Stage target names: `<id>_configure`, `<id>_build`, `<id>_install`.
- `library_import_hint` / `library_import_static_hint` (optional
  4th argument `subdir` was added; old 3-arg calls still work).
- `ensure_build_dir`, path helpers, extra-tool `pkgconf`.
- `BUILDMASTER_VERBOSE`, `BUILDMASTER_FAIL_FAST`,
  `BUILDMASTER_CLEAN_RESET_REPOS`, `BUILDMASTER_DOWNLOADSDIR`.
- Git post-install reset of registered roots.
- Recursive `BUILDMASTER_CONFIGURED` guard (one prefix per tree).

---

## Adding the next breaking wave

Template for a new subsection under `## Unreleased`:

```markdown
### <one-line title>

| Before (X.Y) | After |
|--------------|-------|
| `old_call(...)` | `new_call(...)` |

One paragraph on *why* callers must change. No feature pitch.
```

If the change is additive (new key with a compatible default, new
command that nobody is required to call), it does **not** belong
here. Put it in `CHANGELOG.md` only.
