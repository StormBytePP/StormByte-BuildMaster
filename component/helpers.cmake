# =============================================================================
# component/helpers.cmake — include stub only
# =============================================================================
# Public entry for the component DSL. Nested bootstraps include this file.
# Functionality lives in sibling modules (one file per job).

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

# Parse KEY=value options, library specs, whole-archive item lists.
include("${CMAKE_CURRENT_LIST_DIR}/options.cmake")

# Registry, _bm_comp_create, buildmaster_depend / link / prerequisite.
include("${CMAKE_CURRENT_LIST_DIR}/graph.cmake")

# Inspectable hooks (on_component_materialize / on_graph_finalized).
include("${CMAKE_CURRENT_LIST_DIR}/hooks.cmake")

# Meta components (no sources; membership + INTERFACE).
include("${CMAKE_CURRENT_LIST_DIR}/meta.cmake")

# Meta TOOLCHAIN → members / graph dests (empty child inherits).
include("${CMAKE_CURRENT_LIST_DIR}/toolchain_inherit.cmake")

# Static archive merge (buildmaster_repack).
include("${CMAKE_CURRENT_LIST_DIR}/repack.cmake")

# Deferred materialize + fragment emit + finalize.
include("${CMAKE_CURRENT_LIST_DIR}/materialize.cmake")

# CMake / Meson backends.
include("${CMAKE_CURRENT_LIST_DIR}/backend/helpers.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/factory.cmake")
