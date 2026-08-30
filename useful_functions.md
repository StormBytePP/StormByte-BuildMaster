@page useful_functions "Useful functions"

@section uf_overview Overview

Map of the **source tree** for people who maintain BuildMaster.
It is **not** the public contract (`README.md`) and **not** a
migration guide (`MIGRATE.md`).

Public surface is eight commands
(`.github/tests/expected/public_functions.txt`):

| Command | Role |
|---------|------|
| `buildmaster_component(id title srcdir options mode produced [optstr])` | Factory. Backend from `srcdir`. No builddir |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest)` | `INTERFACE` link + depend when `dest` is a graph node |
| `buildmaster_meta(id title [, optstr])` | `INTERFACE` collection. `REPACK` merges static members |
| `buildmaster_meta_add(meta member…)` | Membership (allowed before `buildmaster_meta`) |
| `buildmaster_hook_component(id fn alias [CAPTURE …])` | After that id materializes |
| `buildmaster_hook_graph(fn alias [CAPTURE …])` | After the whole graph materializes |
| `buildmaster_message(level text [, indent])` | Log. Module is always `USER` |

Everything else is `_bm_<oficio>_…` (or a `helpers.cmake` stub).
Those names are **not** a supported API. They move when the tree
is split. Do not call them from a consumer.

Logging for **callers**: `buildmaster_message(<LEVEL> "<text>" [<indent>])`.
There is no module argument on the public command. Configure
`BUILDMASTER_LOGLEVEL` (`LOWLEVEL`, `DEBUG`, `INFO`, `STATUS`,
`WARNING`, `FATAL`). `BUILDMASTER_DEBUG` is ignored. `WARNING`
and `FATAL` are never filtered.

Internal logging is `_bm_log_message(<MODULE> <LEVEL> "<text>" [<indent>])`.

@section uf_layout Layout

Every `helpers.cmake` is an **include stub**. It includes its
siblings, then the next level down. Do not `include()` a leaf
from the repo root except through that chain.

| Stub | What it pulls |
|------|----------------|
| `helpers.cmake` | `log.cmake`, `paths.cmake`, `lists.cmake`, `library_hints.cmake`, then `toolchain/`, `env/`, `tools/`, `component/` |
| `component/helpers.cmake` | `options/`, `graph/`, `hooks.cmake`, `factory.cmake`, `materialize/`, `meta/`, `repack.cmake`, `backend/` |
| `component/backend/helpers.cmake` | `cmake/`, `meson/` |
| `env/helpers.cmake` | `runner.cmake`, `command.cmake` |
| `toolchain/helpers.cmake` | `validate.cmake`, `profile.cmake`, `flags.cmake`, `msvc.cmake`, `export.cmake` |
| `tools/helpers.cmake` | `add_tool.cmake`, `extra_tools.cmake`, then cmake / meson / file / git / archive |
| `tools/cmake/helpers.cmake` | `stages.cmake` + `templates/` |
| `tools/meson/helpers.cmake` | `stages.cmake` + `templates/` |
| `tools/file/helpers.cmake` | `checksum.cmake`, `download.cmake`, `decompress.cmake` + `templates/` |
| `tools/git/helpers.cmake` | `internal.cmake`, `reset.cmake`, `patch.cmake`, `fetch.cmake`, `switch.cmake` + `templates/` |
| `tools/archive/helpers.cmake` | archiver lookup |

`.cmake.in` templates live under the matching `templates/`
directory, not next to the generator.

There is **no** public `ensure_build_dir`. The graph assigns
`${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` and creates it.

@section uf_modules Modules

@subsection uf_component component/

Registration stores metadata. Materialize runs at the end of
`CMAKE_SOURCE_DIR` via `cmake_language(DEFER)`. An `INTERFACE`
stub named `<id>` exists at registration.

Caller-facing work is the eight commands above plus the trailing
optstr (`INDENT`, `TOOLCHAIN`, `RENAME`, `WHOLE`, `BUILDONLY`,
`STRIPRES`, `REPACK`, `PC={…}`, `LINK=`, `LINKFLAGS=`, `GIT={…}`,
`FILES={…}`). Unknown keys WARNING. Extra positionals FATAL.

Git, downloads, unpack, helper `.pc`, and static merge are
**optstr**, not public helpers.

Stage targets still exist (`<id>_configure` / `_build` /
`_install`). They are implementation, not something a consumer
should `add_dependencies()` by hand — use `buildmaster_depend`
/ `buildmaster_link`.

@subsection uf_tools_cmake tools/cmake/

Writes nested configure / build / install scripts from
`tools/cmake/templates/*.cmake.in` into
`${BUILDMASTER_SCRIPTS_CMAKEDIR}`.

@subsection uf_tools_meson tools/meson/

Same pattern (`setup` / `compile` / `install`). A Meson native
file is written when a toolchain profile is active so compiler
caches stay valid.

@subsection uf_tools_file tools/file/

Internal download / cache / decompress used by `FILES={…}`.
Cache root: `BUILDMASTER_DOWNLOADSDIR`. There is no public
`file_download` / `buildmaster_download`.

@subsection uf_tools_git tools/git/

Internal FETCH / SWITCH / RESET / PATCH used by `GIT={…}`.
Flush order is fixed. Post-install reset runs only when a PATCH
was queued. There is no public `create_git_*`.

@subsection uf_tools_archive tools/archive/

Finds `CMAKE_AR` / `ENV{AR}` / platform fallback. Style is
`msvc_lib` or `gnu_ar`. Used by `RENAME`, `STRIPRES`, `REPACK`.

@subsection uf_env env/

Parent and per-component env runners. Silent runner replays
nested `[BuildMaster/…]` lines live and dumps the full child
log on failure.

@subsection uf_toolchain toolchain/

Profiles: `gcc`, `clang`, `clang-cl`, `msvc` under
`toolchain/profiles/`. Load / validate / export are internal.
The public knob is `TOOLCHAIN=` on the component or meta.

@subsection uf_global helpers.cmake

Path and list helpers used by the rest of the tree
(`_bm_path_*`, `_bm_list_*`). Import hints for IMPORTED
archives are internal. Do not treat them as DSL.

@section uf_log Logging

Public:

```cmake
buildmaster_message(STATUS "Setting up Foo" 1)
```

Internal:

```cmake
_bm_log_message(COMPONENT DEBUG "edge foo -> bar")
```

Modules on the **internal** call include `CORE`, `CMAKE`,
`MESON`, `ENV`, `TOOLCHAIN`, `TOOLS`, `FILE`, `GIT`, `ARCHIVE`,
`RENAME`, `COMPONENT`, `USER`. Callers cannot choose a module;
`buildmaster_message` is always `USER`.

Default level is `STATUS`. `FATAL` is never filtered.
