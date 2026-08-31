# =============================================================================
# tools/extra_tools.cmake — extra-plugin availability and configure
# =============================================================================

## @brief Verify that an extra tool is in `BUILDMASTER_TOOLS_EXTRA_KNOWN`.
## @param[in] tool_name Extra id (`pkgconfig`).
macro(_bm_tools_ensure_extra tool_name)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_ensure_extra(${tool_name})")
	if(NOT BUILDMASTER_TOOLS_EXTRA_KNOWN)
		include("${BUILDMASTER_TOOLS_SRCDIR}/extra/known.cmake")
	endif()
	list(FIND BUILDMASTER_TOOLS_EXTRA_KNOWN "${tool_name}" _found_index)
	if(_found_index EQUAL -1)
		_bm_log_message(TOOLS FATAL
			"The extra tool '${tool_name}' is not available. Known: ${BUILDMASTER_TOOLS_EXTRA_KNOWN}")
	endif()
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_ensure_extra(${tool_name})")
endmacro()

## @brief Include the extra tool's `propagate_vars.cmake` only when enabled.
## @param[in] tool_name Extra id.
macro(_bm_tools_propagate_extra tool_name)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_propagate_extra(${tool_name})")
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	list(FIND configured_extra_tools "${tool_name}" _found_index)
	if(_found_index GREATER -1)
		include("${BUILDMASTER_TOOLS_SRCDIR}/extra/${tool_name}/propagate_vars.cmake")
	endif()
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_propagate_extra(${tool_name})")
endmacro()

## @brief Include `propagate_vars.cmake` for every enabled extra.
macro(_bm_tools_propagate_all_extra)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_propagate_all_extra")
	get_property(configured_extra_tools GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	foreach(tool_name IN LISTS configured_extra_tools)
		include("${BUILDMASTER_TOOLS_SRCDIR}/extra/${tool_name}/propagate_vars.cmake")
	endforeach()
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_propagate_all_extra")
endmacro()

## @brief Demand an extra tool (idempotent).
## @param[in] tool_name Extra id.
macro(_bm_tools_configure_extra tool_name)
	_bm_tools_demand_extra("${tool_name}")
endmacro()

## @brief Compat name. Same as `_bm_tools_demand_extra`.
macro(configure_extra_tool tool_name)
	_bm_tools_demand_extra("${tool_name}")
endmacro()
