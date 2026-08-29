# =============================================================================
# toolchain/validate.cmake — name validation and platform guards
# =============================================================================

## @brief Validate and normalize a BuildMaster toolchain name.
## @param[out] out_normalized Parent-scope variable receiving the lowercased
##            name, or an empty string when @p input is empty (no override).
## @param[in] input Raw toolchain name from the component DSL (may be empty).
## @note Empty input means “use the parent toolchain” and is **not** an error.
## @note Unknown names or platform-incompatible names are fatal and list the
##       known toolchains (`BUILDMASTER_KNOWN_TOOLCHAINS`).
## @note `BUILDMASTER_KNOWN_TOOLCHAINS` may arrive as a CMake list or as a
##       newline/space/comma-separated string from a nested toolchain dump.
##       Both forms are accepted.
## @note Windows-only profiles: `msvc`, `clang-cl`. Non-Windows-only:
##       `gcc`, `clang`.
function(_bm_tc_validate out_normalized input)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_validate")
	string(STRIP "${input}" _t)
	string(TOLOWER "${_t}" _t)

	if(_t STREQUAL "")
		set(${out_normalized} "" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_validate")
		return()
	endif()

	set(_known "${BUILDMASTER_KNOWN_TOOLCHAINS}")
	string(REPLACE "\r" "" _known "${_known}")
	string(REPLACE "\n" ";" _known "${_known}")
	string(REPLACE "," ";" _known "${_known}")
	string(REPLACE " " ";" _known "${_known}")
	list(FILTER _known EXCLUDE REGEX "^$")

	list(FIND _known "${_t}" _idx)
	if(_idx EQUAL -1)
		list(JOIN _known ", " _known_pretty)
		_bm_log_message(TOOLCHAIN FATAL
			"Unknown TOOLCHAIN '${input}'. Known toolchains: ${_known_pretty}"
		)
	endif()

	if(_t STREQUAL "msvc" OR _t STREQUAL "clang-cl")
		if(NOT WIN32)
			list(JOIN _known ", " _known_pretty)
			_bm_log_message(TOOLCHAIN FATAL
				"TOOLCHAIN '${_t}' is only valid on Windows. Known toolchains: ${_known_pretty}"
			)
		endif()
	endif()

	if(_t STREQUAL "gcc" OR _t STREQUAL "clang")
		if(WIN32)
			_bm_log_message(TOOLCHAIN FATAL
				"TOOLCHAIN '${_t}' is not supported on Windows. On Windows use: clang-cl, msvc"
			)
		endif()
	endif()

	set(${out_normalized} "${_t}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG "Validated TOOLCHAIN=${_t}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_validate")
endfunction()
