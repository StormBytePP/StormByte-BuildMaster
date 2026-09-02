include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")

set(_BM_BOOTSTRAP_SETUP_LIST
	ninja
)
string(REPLACE ";" ", " _BM_BOOTSTRAP_SETUP_HDR "${_BM_BOOTSTRAP_SETUP_LIST}")
_bm_log_message(TOOLS STATUS "Setting up tools: ${_BM_BOOTSTRAP_SETUP_HDR}" 1)

add_subdirectory(ninja)

include("${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake")
