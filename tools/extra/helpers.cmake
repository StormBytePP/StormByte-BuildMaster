# =============================================================================
# tools/extra/helpers.cmake
# =============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/known.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/demand.cmake")
