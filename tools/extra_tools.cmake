# =============================================================================
# tools/extra_tools.cmake — extra-plugin availability and configure
# =============================================================================

## @brief Verify that an extra tool is listed in
##        `BUILDMASTER_PLUGINS_EXTRA_AVAILABLE`.
## @param[in] tool_name Name of the extra tool to check.
## @note Reads the global property
##       `BUILDMASTER_PLUGINS_EXTRA_AVAILABLE` and calls
##       `_bm_log_message(TOOLS FATAL ...)` if `tool_name` is not found.
##       Use this check before performing operations that require the extra
##       tool.
macro(ensure_extra_tool_is_available tool_name)
	_bm_log_message(TOOLS LOWLEVEL "Entering ensure_extra_tool_is_available(${tool_name})")
	get_property(available_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_AVAILABLE)
	list(FIND available_extra_tools "${tool_name}" _found_index)
	if(_found_index EQUAL -1)
		_bm_log_message(TOOLS FATAL "The extra tool '${tool_name}' is not available. Available extra tools are: ${available_extra_tools}")
	endif()
	_bm_log_message(TOOLS LOWLEVEL "Exiting ensure_extra_tool_is_available(${tool_name})")
endmacro()

## @brief Include the extra tool's `propagate_vars.cmake` only when the
##        tool is enabled.
## @param[in] tool_name Name of the extra tool.
## @note Reads the global property `BUILDMASTER_PLUGINS_EXTRA_ENABLED` and
##       includes `${tool_name}/propagate_vars.cmake` when present. No
##       effect if the tool is not enabled.
macro(propagate_vars_extra_tool tool_name)
	_bm_log_message(TOOLS LOWLEVEL "Entering propagate_vars_extra_tool(${tool_name})")
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	list(FIND configured_extra_tools "${tool_name}" _found_index)
	if(_found_index GREATER -1)
		include(${tool_name}/propagate_vars.cmake)
	endif()
	_bm_log_message(TOOLS LOWLEVEL "Exiting propagate_vars_extra_tool(${tool_name})")
endmacro()

## @brief Include `propagate_vars.cmake` for all extra tools enabled via
##        `BUILDMASTER_PLUGINS_EXTRA_ENABLED`.
## @note Inclusion errors will propagate as CMake errors.
macro(propagate_all_vars_extra_tools)
	_bm_log_message(TOOLS LOWLEVEL "Entering propagate_all_vars_extra_tools")
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	foreach(tool_name IN LISTS configured_extra_tools)
		include(${BUILDMASTER_TOOLS_SRCDIR}/extra/${tool_name}/propagate_vars.cmake)
	endforeach()
	_bm_log_message(TOOLS LOWLEVEL "Exiting propagate_all_vars_extra_tools")
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
	_bm_log_message(TOOLS LOWLEVEL "Entering configure_extra_tool(${tool_name})")
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)

	list(FIND configured_extra_tools "${tool_name}" _found_index)

	if(_found_index EQUAL -1)
		list(APPEND configured_extra_tools "${tool_name}")

		set_property(GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED
					"${configured_extra_tools}")

		add_subdirectory(${tool_name})
		include(${tool_name}/propagate_vars.cmake)
	endif()
	_bm_log_message(TOOLS LOWLEVEL "Exiting configure_extra_tool(${tool_name})")
endmacro()
