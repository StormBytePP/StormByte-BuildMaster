@page useful_functions "Useful functions"

@section uf_overview Overview

This page collects short, hand-curated descriptions of the most
useful helper modules provided by BuildMaster. It is intended as a
quick reference for maintainers and integrators — full signatures and
examples are available in the source files linked below.

@section uf_tools Useful functions

@subsection uf_tools_cmake tools/cmake/helpers.cmake

Creates platform-aware `configure`, `build` and `install` fragment
scripts for CMake-built components. The generator writes files into
`${BUILDMASTER_SCRIPTS_CMAKEDIR}` and exposes template variables such
as `_CMAKE_COMPONENT_TITLE`, `_CMAKE_SRCDIR`, `_CMAKE_BUILD_DIR` and
`_CMAKE_OUTPUT_LIBRARIES` for use by the templates.

Source: tools/cmake/helpers.cmake

@subsection uf_tools_core tools/helpers.cmake

High-level helpers to register and configure external tools. Includes
macros to add tool subdirectories, conditionally include
`propagate_vars.cmake` from tools, and ensure extra tools are
available/enabled.

Source: tools/helpers.cmake

@subsection uf_tools_meson tools/meson/helpers.cmake

Generates setup/compile/install fragment scripts for Meson-built
components. Produces `_MESON_OPTIONS` and `_MESON_OUTPUT_LIBRARIES`
template variables and handles library mode differences (static vs
shared).

Source: tools/meson/helpers.cmake

@subsection uf_tools_git tools/git/helpers.cmake

Small generators that create CMake fragments to perform git actions
(`patch`, `reset`, `fetch`, `switch`). These fragments are intended to
be executed by the bootstrap process to manipulate upstream sources.

Source: tools/git/helpers.cmake

@subsection uf_component component/helpers.cmake

Component-level helpers which assemble per-component generator
fragments, compute canonical import/static/DLL filenames and generate
bundler or rename scripts for installed static libraries.

Source: component/helpers.cmake

@subsection uf_env env/helpers.cmake

Helpers to produce platform-specific runner scripts (shell/batch) and
to tokenize command lists for safe use with
`execute_process(COMMAND ...)`.

Source: env/helpers.cmake

@subsection uf_global helpers.cmake

Top-level utilities: path normalization, library filename hints,
`sanitize_for_filename`, and `list_join` (a safe list-joining helper
that preserves quoted semicolons). These are widely used across the
bootstrap and generator scripts.

Source: helpers.cmake

