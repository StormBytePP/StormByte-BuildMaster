## @brief Add and configure a build subdirectory for a third-party tool.
## @param[in] srcdir Relative path to the tool's source directory. The path is
##            interpreted relative to this helpers.cmake file's directory.
## @param[in] indent_level Optional number of tab characters to prepend to the
##            status message. Defaults to no indentation.
## @note Prints a status message (optionally indented). Calls
##       `add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/${srcdir}")` and
##       includes `${CMAKE_CURRENT_LIST_DIR}/${srcdir}/propagate_vars.cmake`
##       to import propagation variables defined by the tool. This macro
##       does not validate the presence of `CMakeLists.txt` or
##       `propagate_vars.cmake` in `srcdir`.
## @example
##   add_tool(myplugin)        # No indentation
##   add_tool(myplugin 2)      # Prints: "\t\tSetting up myplugin"
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

## @brief Verify that an extra tool is listed in
##        `BUILDMASTER_PLUGINS_EXTRA_AVAILABLE`.
## @param[in] tool_name Name of the extra tool to check.
## @note Reads the global property
##       `BUILDMASTER_PLUGINS_EXTRA_AVAILABLE` and calls
##       `message(FATAL_ERROR ...)` if `tool_name` is not found. Use this
##       check before performing operations that require the extra tool.
macro(ensure_extra_tool_is_available tool_name)
	# Append the tool name to the global property BUILDMASTER_PLUGINS_EXTRA
	get_property(available_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_AVAILABLE)
	list(FIND available_extra_tools "${tool_name}" _found_index)
	if(_found_index EQUAL -1)
		message(FATAL_ERROR "The extra tool '${tool_name}' is not available. Available extra tools are: ${available_extra_tools}")
	endif()
endmacro()

## @brief Include the extra tool's `propagate_vars.cmake` only when the
##        tool is enabled.
## @param[in] tool_name Name of the extra tool.
## @note Reads the global property `BUILDMASTER_PLUGINS_EXTRA_ENABLED` and
##       includes `${tool_name}/propagate_vars.cmake` when present. No
##       effect if the tool is not enabled.
macro(propagate_vars_extra_tool tool_name)
	# Append the tool name to the global property BUILDMASTER_PLUGINS_EXTRA
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	list(FIND configured_extra_tools "${tool_name}" _found_index)
	if(_found_index GREATER -1)
		include(${tool_name}/propagate_vars.cmake)
	endif()
endmacro()

## @brief Include `propagate_vars.cmake` for all extra tools enabled via
##        `BUILDMASTER_PLUGINS_EXTRA_ENABLED`.
## @note Inclusion errors will propagate as CMake errors.
macro(propagate_all_vars_extra_tools)
	# Get the list of configured extra tools
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	foreach(tool_name IN LISTS configured_extra_tools)
		include(${BUILDMASTER_TOOLS_SRCDIR}/extra/${tool_name}/propagate_vars.cmake)
	endforeach()
endmacro()

## @brief Ensure an extra tool is available and configure it if not already
##        enabled.
## @param[in] tool_name Name of the extra tool.
## @note Calls `ensure_extra_tool_is_available`. If the tool is not yet
##       registered in `BUILDMASTER_PLUGINS_EXTRA_ENABLED` this macro
##       appends it, writes back the global property, calls
##       `add_subdirectory(${tool_name})` and includes
##       `${tool_name}/propagate_vars.cmake`.
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