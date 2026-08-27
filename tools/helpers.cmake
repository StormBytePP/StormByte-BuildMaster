# =============================================================================
# tools/helpers.cmake — include stub only
# =============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/add_tool.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/extra_tools.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/pkgconfig/helpers.cmake")
