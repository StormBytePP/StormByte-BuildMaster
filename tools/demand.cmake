# =============================================================================
# tools/demand.cmake — on-request tool init
# =============================================================================

## @brief Enable `tools/<name>` once. Further calls are no-ops.
## @param[in] name `cmake`, `meson`, `git`, or `file`.
function(_bm_tools_demand_named name)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_demand_named(${name})")
	if("${name}" STREQUAL "")
		_bm_log_message(TOOLS FATAL "_bm_tools_demand_named: empty name")
	endif()
	if(name STREQUAL "ninja" OR name STREQUAL "archiver" OR name STREQUAL "extra")
		_bm_log_message(TOOLS FATAL
			"_bm_tools_demand_named('${name}'): not an on-demand tool")
	endif()

	get_property(_enabled GLOBAL PROPERTY BUILDMASTER_TOOLS_ENABLED)
	set(_hit -1)
	if(_enabled)
		list(FIND _enabled "${name}" _hit)
	endif()
	if(NOT _hit EQUAL -1)
		_bm_log_message(TOOLS LOWLEVEL
			"Exiting _bm_tools_demand_named(${name}) (enabled)")
		return()
	endif()

	_bm_log_message(TOOLS STATUS "Setting up tools: ${name}" 1)
	_bm_tools_add("${name}" 2)
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_demand_named(${name})")
endfunction()
