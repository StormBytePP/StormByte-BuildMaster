include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")

add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/bootstrap")

_bm_log_message(TOOLS STATUS "Setting up tools: extra" 1)
_bm_tools_add(extra 2)

include("${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake")
