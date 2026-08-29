include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

_bm_log_message(TOOLS STATUS "Setting up tools..." 1)

# Initialize variables
include("${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake")

# Include our helpers
include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")

_bm_tools_add(cmake 2)
_bm_tools_add(git 2)
_bm_tools_add(meson 2)
_bm_tools_add(ninja 2)
_bm_tools_add(extra 2)
_bm_tools_add(file 2)

include("${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake")
