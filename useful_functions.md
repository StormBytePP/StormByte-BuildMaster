@page useful_functions "Useful functions"

@section uf_overview Overview

Short reference for BuildMaster helper modules. Full signatures live in the
linked sources. Every `helpers.cmake` is an **include stub**; the
implementation sits in one file per oficio next to it.

Logging is `buildmaster_message(<MODULE> <LEVEL> …)`. Configure
`BUILDMASTER_LOGLEVEL` (`FATAL`, `WARNING`, `STATUS`, `INFO`, `DEBUG`,
`LOWLEVEL`). `BUILDMASTER_DEBUG` is ignored. Prefer this API over
`message()` in projects that use BuildMaster.

@section uf_layout Layout

| Stub | Oficio files |
|------|----------------|
| `helpers.cmake` | `paths.cmake`, `library_hints.cmake`, `lists.cmake` — then includes toolchain / env / tools / component trees |
| `component/helpers.cmake` | `options.cmake`, `graph.cmake`, `materialize.cmake` (+ `meta.cmake`, `repack.cmake`; backends `component/{cmake,meson}/`) |
| `env/helpers.cmake` | `runner.cmake`, `command.cmake` |
| `toolchain/helpers.cmake` | `validate.cmake`, `profile.cmake`, `flags.cmake`, `msvc.cmake`, `export.cmake` |
| `tools/helpers.cmake` | `_bm_tools_add.cmake`, `extra_tools.cmake` |
| `tools/cmake/helpers.cmake` | `stages.cmake` |
| `tools/meson/helpers.cmake` | `stages.cmake` |
| `tools/file/helpers.cmake` | `checksum.cmake`, `download.cmake`, `decompress.cmake` |
| `tools/git/helpers.cmake` | `git_internal.cmake`, `reset.cmake`, `patch.cmake`, `fetch.cmake`, `switch.cmake` |
| `tools/archive/helpers.cmake` | `find_archiver.cmake` |

@section uf_modules Modules

@subsection uf_component component/

Declarative component API (order of declaration does not matter; materialize
is deferred to the end of `CMAKE_SOURCE_DIR`):

- `_bm_comp_create()` — core factory
- `create_cmake_component()` / `create_meson_component()`
- `create_cmake_headers_component()` / `create_meson_headers_component()`
- `component_dependency()`, `component_link()`, `component_prerequisite()`
- `component_repack()` — merge static archives after inputs' `_build`
- `meta_component()` / `meta_component_add()` — INTERFACE collections

Trailing options string (`KEY=value;FLAG`): `INDENT`, `TOOLCHAIN`, `RENAME`,
`BUILDONLY`, `WHOLE`. Unknown keys warn. Extra positional arguments are fatal.

Generated fragments live under `${BUILDMASTER_SCRIPTS_COMPONENTDIR}`. Stage
targets are `<id>_configure` / `<id>_build` / `<id>_install` plus IMPORTED
or INTERFACE libraries.

@subsection uf_tools_cmake tools/cmake/

`_bm_backend_cmake_stages()` — writes configure / build / install scripts into
`${BUILDMASTER_SCRIPTS_CMAKEDIR}` from `tools/cmake/*.cmake.in`.

@subsection uf_tools_meson tools/meson/

`_bm_backend_meson_stages()` — same pattern (`setup` / `compile` / `install`).
Always pass a Meson native file when a toolchain profile is active so
compiler caches stay valid.

@subsection uf_tools_file tools/file/

- `file_download()` / `file_download_cached()` — hash-verified download;
  cache under `BUILDMASTER_DOWNLOADSDIR` (override with env / `-D`)
- `file_decompress()` — `file(ARCHIVE_EXTRACT …)`

@subsection uf_tools_git tools/git/

Bootstrap Git fragments:

- `create_git_fetch()`
- `create_git_reset_file()`
- `create_git_patch_file()`
- `create_git_switch_branch()`

Post-install reset is registered automatically when a component id is bound
to a git root.

@subsection uf_tools_archive tools/archive/

`buildmaster_find_archiver(out_path out_style [hint])` — `CMAKE_AR`,
`ENV{AR}`, then platform fallbacks. Style is `msvc_lib` or `gnu_ar`.

@subsection uf_env env/

- `_bm_env_update_runner()` — regenerate the parent platform runner
- `_bm_env__bm_comp_create_runners()` — per-component runners
  after a toolchain profile load
- `_bm_env_prepare_command()` — tokenize for `execute_process(COMMAND …)`
- `_bm_env_quote_cmd_list()` — quote tokens for generated `-P` scripts

@subsection uf_toolchain toolchain/

- `buildmaster_validate_toolchain()` / `buildmaster_load_toolchain_profile()`
- `_bm_tc_clean_cflags()` / `_bm_tc_clean_ldflags()`
- `_bm_tc_fuse_ld_flag()`
- `_bm_tc_resolve_msvc_tool()`
- `_bm_tc_reset()` / `export()` / `export_raw()` / `write()` /
  `write_component()`

Profiles: `gcc`, `clang`, `clang-cl`, `msvc` under `toolchain/profiles/`.

@subsection uf_tools_core tools/

Tool registration: `_bm_tools_add`, `_bm_tools_configure_extra`,
`_bm_tools_ensure_extra`, extra-plugin propagation (e.g. pkgconf).

@subsection uf_global helpers.cmake

Shared utilities (loaded first):

- `_bm_path_windows()`, `_bm_path_normalize()`, `sanitize_for_filename()`,
  `ensure_build_dir()`
- `library_import_hint()`, `library_import_static_hint()`
- `_bm_list_toggle_bool()`, `_bm_list_join()`
- Then includes toolchain, env, cmake/file/git/meson/archive, component

@section uf_log Logging

`buildmaster_message(<MODULE> <LEVEL> <text> [<indent>])`

Modules include `CORE`, `CMAKE`, `MESON`, `ENV`, `TOOLCHAIN`, `TOOLS`,
`FILE`, `GIT`, `ARCHIVE`, `RENAME`, `COMPONENT`, `USER`.

`FATAL` is never filtered. `WARNING` is shown at `WARNING` and above.
Default level is `STATUS`.