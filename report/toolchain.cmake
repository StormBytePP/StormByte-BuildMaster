# =============================================================================
# report/toolchain.cmake — parent toolchain block
# =============================================================================

## @brief One toolchain row (always printed; value may be empty).
## @param[in] _key   Label (`C compiler`, `C flags`, …).
## @param[in] _value Display value.
## @param[in] _width Key column width.
function(_bm_report_toolchain_row _key _value _width)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_toolchain_row")
	_bm_report_pad("${_key}" "${_width}" _k)
	_bm_report_wrap("${_value}" 88 _lines)
	if(NOT _lines)
		_bm_log_message(REPORT STATUS "${_k}" 2)
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_toolchain_row")
		return()
	endif()
	set(_first TRUE)
	foreach(_ln IN LISTS _lines)
		if(_first)
			_bm_log_message(REPORT STATUS "${_k}${_ln}" 2)
			set(_first FALSE)
		else()
			_bm_report_pad("" "${_width}" _blank)
			_bm_log_message(REPORT STATUS "${_blank}${_ln}" 2)
		endif()
	endforeach()
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_toolchain_row")
endfunction()

## @brief Dump the parent toolchain BuildMaster used for this configure.
## @note Compiler paths are absolute. Launcher is the file name, or
##       `(none)`. Empty `CMAKE_LINKER` prints `(compiler default)`.
## @note These are BM globals, not per-component overrides. The host
##       may still add flags after this block.
function(_bm_report_toolchain)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_toolchain")
	_bm_log_message(REPORT STATUS "Toolchain" 1)

	set(_launch "${CMAKE_C_COMPILER_LAUNCHER}")
	if(_launch STREQUAL "")
		set(_launch_name "(none)")
	else()
		get_filename_component(_launch_name "${_launch}" NAME)
	endif()
	if("${CMAKE_LINKER}" STREQUAL "")
		set(_ld "(compiler default)")
	else()
		set(_ld "${CMAKE_LINKER}")
	endif()

	set(_w 18)
	_bm_report_toolchain_row("C compiler" "${CMAKE_C_COMPILER}" ${_w})
	_bm_report_toolchain_row("C++ compiler" "${CMAKE_CXX_COMPILER}" ${_w})
	_bm_report_toolchain_row("Launcher" "${_launch_name}" ${_w})
	_bm_report_toolchain_row("Linker" "${_ld}" ${_w})
	_bm_report_toolchain_row("C flags" "${CMAKE_C_FLAGS}" ${_w})
	_bm_report_toolchain_row("C++ flags" "${CMAKE_CXX_FLAGS}" ${_w})
	_bm_report_toolchain_row("Exe linker" "${CMAKE_EXE_LINKER_FLAGS}" ${_w})
	_bm_report_toolchain_row("Shared linker" "${CMAKE_SHARED_LINKER_FLAGS}" ${_w})

	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_toolchain")
endfunction()
