# =============================================================================
# tools/helpers.cmake — include stub only
# =============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/add_tool.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/demand.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/bootstrap/helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/extra_tools.cmake")
