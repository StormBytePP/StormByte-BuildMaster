# Initialize variables and functions needed for extra tools
include(${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake)

# Configure requested extra tools
if(DEFINED BUILDMASTER_INITIALIZE_EXTRA_TOOLS)
	foreach(tool_name IN LISTS BUILDMASTER_INITIALIZE_EXTRA_TOOLS)
		configure_extra_tool(${tool_name})
	endforeach()
endif()

include(${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake)