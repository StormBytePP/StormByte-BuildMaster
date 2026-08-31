# =============================================================================
# tools/extra/demand.cmake — on-request extra tools
# =============================================================================

## @brief Enable `tools/extra/<id>` once.
## @param[in] id Token from `REQUIRE_TOOL` / `BUILDMASTER_TOOLS_EXTRA_KNOWN`.
## @note Unknown id or missing directory is FATAL (never fall through to
##       a same-named system binary).
## @note `add_subdirectory` runs `tools/extra/<id>/CMakeLists.txt`, which
##       must call `_bm_extra_<id>_init` and then include `propagate_vars`.
function(_bm_tools_demand_extra id)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_demand_extra(${id})")
	if("${id}" STREQUAL "")
		_bm_log_message(TOOLS FATAL "_bm_tools_demand_extra: empty id")
	endif()

	if(NOT BUILDMASTER_TOOLS_EXTRA_KNOWN)
		include("${BUILDMASTER_TOOLS_SRCDIR}/extra/known.cmake")
	endif()
	list(FIND BUILDMASTER_TOOLS_EXTRA_KNOWN "${id}" _known)
	if(_known EQUAL -1)
		_bm_log_message(TOOLS FATAL
			"REQUIRE_TOOL='${id}' is not a BuildMaster extra tool. Known: ${BUILDMASTER_TOOLS_EXTRA_KNOWN}")
	endif()

	set(_src "${BUILDMASTER_TOOLS_SRCDIR}/extra/${id}")
	if(NOT IS_DIRECTORY "${_src}")
		_bm_log_message(TOOLS FATAL
			"REQUIRE_TOOL='${id}' is listed but tools/extra/${id} is missing")
	endif()

	get_property(_enabled GLOBAL PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED)
	set(_hit -1)
	if(_enabled)
		list(FIND _enabled "${id}" _hit)
	endif()
	if(NOT _hit EQUAL -1)
		_bm_log_message(TOOLS LOWLEVEL
			"Exiting _bm_tools_demand_extra(${id}) (enabled)")
		return()
	endif()

	if(NOT BUILDMASTER_TOOLS_BINDIR OR BUILDMASTER_TOOLS_BINDIR STREQUAL "")
		_bm_log_message(TOOLS FATAL
			"_bm_tools_demand_extra: BUILDMASTER_TOOLS_BINDIR is empty")
	endif()

	_bm_log_message(TOOLS STATUS "Setting up tools: ${id}" 1)
	add_subdirectory("${_src}" "${BUILDMASTER_TOOLS_BINDIR}/extra/${id}")

	if(NOT COMMAND _bm_extra_${id}_init)
		_bm_log_message(TOOLS FATAL
			"extra '${id}' has no _bm_extra_${id}_init")
	endif()

	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_PLUGINS_EXTRA_ENABLED "${id}")
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_demand_extra(${id})")
endfunction()
