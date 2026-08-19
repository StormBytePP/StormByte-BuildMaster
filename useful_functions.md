@page useful_functions "Useful functions"

@section uf_overview Overview

Short reference for BuildMaster helper modules. Full signatures and
implementation details live in the linked sources.

@section uf_tools Modules

@subsection uf_component component/helpers.cmake

High-level component API:

- `create_component()` — core factory (CMake or Meson, static/shared)
- `create_cmake_component()` / `create_meson_component()`
- `create_cmake_dependant_component()` / `create_meson_dependant_component()`
- `library_import_hint()`, `library_import_static_hint()`, `library_dll_hint()`
- `rename_static_library()`, `create_bundle_static_libraries()`

Generates per-component fragments under `${BUILDMASTER_SCRIPTS_COMPONENTDIR}`
and wires `<component>_build` / `<component>_install` plus IMPORTED targets.

@subsection uf_tools_cmake tools/cmake/helpers.cmake

`create_cmake_stages()` — writes configure/build/install scripts into
`${BUILDMASTER_SCRIPTS_CMAKEDIR}` from `tools/cmake/*.cmake.in`.

@subsection uf_tools_meson tools/meson/helpers.cmake

`create_meson_stages()` — same pattern for Meson (`setup` / `compile` /
`install` templates). Handles static vs shared and MSVC `/Z7` for parallel
builds when applicable.

@subsection uf_tools_git tools/git/helpers.cmake

Generators for bootstrap Git fragments:

- `create_git_fetch()`
- `create_git_reset_file()`
- `create_git_patch_file()`
- `create_git_switch_branch()`

@subsection uf_env env/helpers.cmake

- `update_env_runner()` — regenerate platform runner scripts
- `prepare_command()` — tokenize a command list for `execute_process(COMMAND …)`

@subsection uf_tools_core tools/helpers.cmake

Tool registration macros: `add_tool`, `configure_extra_tool`,
`ensure_extra_tool_is_available`, propagation helpers for extra plugins
(e.g. pkgconf).

@subsection uf_global helpers.cmake

Shared utilities:

- `sanitize_for_filename()` — safe ids for generated script names
- `list_join()` — join lists while respecting quoted segments
- `windows_path()`, library filename hints
- Includes env/cmake/git/meson/component helper trees

@section uf_debug Debug output

Set environment variable `BUILDMASTER_DEBUG=1` before configuring to
propagate full configure/build tool logs through BuildMaster stages.
