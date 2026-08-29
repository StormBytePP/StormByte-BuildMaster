# =============================================================================
# component/helpers.cmake — include stub only
# =============================================================================
# Public entry for the component DSL. Nested bootstraps include this file.
# Functionality lives in sibling modules (one file per job).

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

# Parse KEY=value options, library specs, whole-archive item lists.
include("${CMAKE_CURRENT_LIST_DIR}/options.cmake")

# Registry, create_component, component_dependency / link / prerequisite.
include("${CMAKE_CURRENT_LIST_DIR}/graph.cmake")

# Inspectable hooks (on_component_materialize / on_graph_finalized).
include("${CMAKE_CURRENT_LIST_DIR}/hooks.cmake")

# Meta components (no sources; membership + INTERFACE).
include("${CMAKE_CURRENT_LIST_DIR}/meta.cmake")

# Meta TOOLCHAIN → members / graph dests (empty child inherits).
include("${CMAKE_CURRENT_LIST_DIR}/toolchain_inherit.cmake")

# Static archive merge (component_repack).
include("${CMAKE_CURRENT_LIST_DIR}/repack.cmake")

# Deferred materialize + fragment emit + finalize.
include("${CMAKE_CURRENT_LIST_DIR}/materialize.cmake")

# Backend wrappers (create_cmake_* / create_meson_*).
include("${CMAKE_CURRENT_LIST_DIR}/cmake/helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/meson/helpers.cmake")
