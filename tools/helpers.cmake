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

## ensure_extra_tool_is_available(tool_name)
# Description:
#   Verify that `tool_name` is listed in the global property
#   `BUILDMASTER_PLUGINS_EXTRA_AVAILABLE`.
#
# Parameters:
#   tool_name - Name of the extra tool to check.
#
# Behavior:
#   - Reads the global property `BUILDMASTER_PLUGINS_EXTRA_AVAILABLE`.
#   - Searches for `tool_name` and calls `message(FATAL_ERROR ...)` if not found.
#
# Notes:
#   - This macro halts configuration when the tool is not available.
#   - Intended to be used before operations that assume the tool exists.
macro(ensure_extra_tool_is_available tool_name)
	# Append the tool name to the global property BUILDMASTER_PLUGINS_EXTRA
	get_property(available_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_AVAILABLE)
	list(FIND available_extra_tools "${tool_name}" _found_index)
	if(_found_index EQUAL -1)
		message(FATAL_ERROR "The extra tool '${tool_name}' is not available. Available extra tools are: ${available_extra_tools}")
	endif()
endmacro()

## propagate_vars_extra_tool(tool_name)
# Description:
#   Include the tool's `propagate_vars.cmake` file only if the tool is enabled
#   in `BUILDMASTER_PLUGINS_EXTRA_ENABLED`.
#
# Parameters:
#   tool_name - Name of the extra tool.
#
# Behavior:
#   - Reads `BUILDMASTER_PLUGINS_EXTRA_ENABLED`.
#   - If `tool_name` is present, runs `include(${tool_name}/propagate_vars.cmake)`.
#
# Notes:
#   - No-op if the tool is not enabled.
macro(propagate_vars_extra_tool tool_name)
	# Append the tool name to the global property BUILDMASTER_PLUGINS_EXTRA
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	list(FIND configured_extra_tools "${tool_name}" _found_index)
	if(_found_index GREATER -1)
		include(${tool_name}/propagate_vars.cmake)
	endif()
endmacro()

## propagate_all_vars_extra_tools()
# Description:
#   Include `propagate_vars.cmake` for all extra tools listed in
#   `BUILDMASTER_PLUGINS_EXTRA_ENABLED`.
#
# Parameters:
#   None.
#
# Behavior:
#   - Reads `BUILDMASTER_PLUGINS_EXTRA_ENABLED` and includes each tool's
#     `propagate_vars.cmake`.
#
# Notes:
#   - Inclusion errors will propagate as CMake errors.
macro(propagate_all_vars_extra_tools)
	# Get the list of configured extra tools
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	foreach(tool_name IN LISTS configured_extra_tools)
		include(${BUILDMASTER_TOOLS_SRCDIR}/extra/${tool_name}/propagate_vars.cmake)
	endforeach()
endmacro()

## configure_extra_tool(tool_name)
# Description:
#   Ensure a tool is available and, if not already configured, add it to the
#   build and propagate its variables.
#
# Parameters:
#   tool_name - Name of the extra tool.
#
# Behavior:
#   - Calls `ensure_extra_tool_is_available(${tool_name})`.
#   - If the tool is not present in `BUILDMASTER_PLUGINS_EXTRA_ENABLED`, runs
#     `add_subdirectory(${tool_name})` and includes
#     `${tool_name}/propagate_vars.cmake`.
#
# Notes:
#   - This macro modifies the project configuration by adding a subdirectory.
macro(configure_extra_tool tool_name)
	# Read the list of already-enabled tools (may be undefined)
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)

	# Check if the tool is already registered
	list(FIND configured_extra_tools "${tool_name}" _found_index)

	if(_found_index EQUAL -1)
		# Append cleanly using list(APPEND) — works even if the variable is undefined
		list(APPEND configured_extra_tools "${tool_name}")

		# Write back to the global property
		set_property(GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED
					"${configured_extra_tools}")

		# Add the tool directory and propagate its variables
		add_subdirectory(${tool_name})
		include(${tool_name}/propagate_vars.cmake)
	endif()
endmacro()