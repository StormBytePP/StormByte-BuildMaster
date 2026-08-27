# =============================================================================
# toolchain/helpers.cmake — include stub
# =============================================================================
# Public API is unchanged: include(toolchain/helpers.cmake) still loads the
# full toolchain DSL. Implementations live in one file per oficio.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/validate.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/profile.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/flags.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/msvc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/export.cmake")
