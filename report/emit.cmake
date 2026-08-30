# =============================================================================
# report/emit.cmake — last BuildMaster configure line
# =============================================================================

## @brief Whether this process is a nested backend configure.
## @param[out] _out Parent-scope TRUE if CMAKE_TOOLCHAIN_FILE points at
##             BuildMaster's generated toolchain.cmake.
## @note A host that inherited that file already saw the parent dump.
function(_bm_report_is_nested _out)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_is_nested")
	set(_nested FALSE)
	if(CMAKE_TOOLCHAIN_FILE)
		get_filename_component(_tcn "${CMAKE_TOOLCHAIN_FILE}" NAME)
		if(_tcn STREQUAL "toolchain.cmake")
			string(FIND "${CMAKE_TOOLCHAIN_FILE}" "buildmaster" _hit)
			if(NOT _hit EQUAL -1)
				set(_nested TRUE)
			endif()
		endif()
	endif()
	set(${_out} "${_nested}" PARENT_SCOPE)
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_is_nested")
endfunction()

## @brief Emit `BuildMaster <version> Configuration:` or return silently.
## @note Not public. Called once from `_bm_materialize_finalize` after
##       graph hooks. Last BuildMaster STATUS in this configure.
## @note Gated on `BUILDMASTER_VERBOSE` (ON). Off → no output.
## @note Nested backend configure does not emit.
## @note Idempotent via GLOBAL `BUILDMASTER_REPORT_EMITTED`.
function(_bm_report_emit)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_emit")

	get_property(_once GLOBAL PROPERTY BUILDMASTER_REPORT_EMITTED)
	if(_once)
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_emit (already)")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_REPORT_EMITTED TRUE)

	if(NOT BUILDMASTER_VERBOSE STREQUAL "ON")
		_bm_log_message(REPORT DEBUG "_bm_report_emit: VERBOSE off")
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_emit")
		return()
	endif()

	_bm_report_is_nested(_nested)
	if(_nested)
		_bm_log_message(REPORT DEBUG "_bm_report_emit: nested toolchain, skip")
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_emit")
		return()
	endif()

	set(_ver "${BUILDMASTER_VERSION}")
	if(_ver STREQUAL "")
		set(_ver "unknown")
	endif()
	_bm_log_message(REPORT STATUS "BuildMaster ${_ver} Configuration:")
	_bm_report_toolchain()
	_bm_report_components()

	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_emit")
endfunction()
