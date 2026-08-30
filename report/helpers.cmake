# =============================================================================
# report/helpers.cmake — include stub
# =============================================================================
# Verbose configure dump ("BuildMaster Configuration:"). Not a public API.
# Load order: format first (pad / wrap / labels), then the two blocks,
# emit last (it calls them).

include("${CMAKE_CURRENT_LIST_DIR}/format.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/toolchain.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/components.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/emit.cmake")
