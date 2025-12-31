## add_tool(srcdir [indent_level])
# Description:
#   Add and configure a build subdirectory for a third-party tool.
#
# Parameters:
#   srcdir        - Relative path to the tool's source directory (relative to
#                   this helpers.cmake file's directory).
#   indent_level  - (Optional) Number of tab characters to prepend to the
#                   status message. Defaults to no indentation.
#
# Behavior:
#   - Prints a status message: "Configuring <srcdir>", optionally indented
#     with <indent_level> tab characters.
#   - Calls `add_subdirectory(<srcdir>)` to include the tool in the build.
#   - Includes "${CMAKE_CURRENT_LIST_DIR}/${srcdir}/propagate_vars.cmake"
#     to import or propagate variables that the tool defines for the
#     surrounding bootstrap build.
#
# Notes:
#   - `srcdir` should contain a `CMakeLists.txt` and a
#     `propagate_vars.cmake` file; this macro does not verify their
#     existence before calling `add_subdirectory` and `include`.
#   - Intended for use in the bootstrap helpers to register bundled
#     plugin/tool directories.
#
# Example:
#   add_tool(myplugin)        # No indentation
#   add_tool(myplugin 2)      # Prints: "\t\tConfiguring myplugin"
macro(add_tool srcdir)
	# Optional indent level
	if(${ARGC} GREATER 1)
		set(_indent_level "${ARGV1}")
		string(REPEAT "\t" ${_indent_level} _INDENT_)
	else()
		set(_INDENT_ "")
	endif()

	message(STATUS "${_INDENT_}Setting up ${srcdir}")
	add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/${srcdir}")
	include("${CMAKE_CURRENT_LIST_DIR}/${srcdir}/propagate_vars.cmake")
endmacro()