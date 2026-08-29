# =============================================================================
# component/options.cmake — options string + library specs
# =============================================================================
# Loaded from component/helpers.cmake. Does not include backends.
# Implementation lives in component/options/*.cmake.

include("${CMAKE_CURRENT_LIST_DIR}/options/core.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/options/pc.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/options/link.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/options/linkflags.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/options/git.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/options/parse.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/options/spec.cmake")
