message(STATUS "\tSetting up tools...")

# Initialize variables
include("${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake")

# Include our helpers
include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")

add_tool(cmake 2)
add_tool(git 2)
add_tool(meson 2)
add_tool(ninja 2)
add_tool(extra 2)
include("${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake")