# =============================================================================
# env/helpers.cmake — include stub
# =============================================================================
# Public API is unchanged: include(env/helpers.cmake) still loads every env
# helper. Implementations live in one file per oficio so the DSL stays
# maintainable (especially when included recursively from nested bootstraps).

include("${CMAKE_CURRENT_LIST_DIR}/runner.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/command.cmake")
