# Initialize variables
include("${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/resolve.cmake")

_bm_extra_pkgconfig_init()

# Propagate environment variables to parent scope
include("${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake")
