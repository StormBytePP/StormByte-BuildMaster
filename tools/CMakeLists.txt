include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

# Hardcoded until demand-load knows the real subset.
set(_BM_TOOL_SETUP_LIST
	cmake
	git
	meson
	ninja
	extra
	file
	archive
	bundle
	pkgconfig
	rename
)
string(REPLACE ";" ", " _BM_TOOL_SETUP_HDR "${_BM_TOOL_SETUP_LIST}")
_bm_log_message(TOOLS STATUS "Setting up tools: ${_BM_TOOL_SETUP_HDR}" 1)

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
