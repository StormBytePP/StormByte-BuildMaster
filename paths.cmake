# =============================================================================
# paths.cmake — path normalization and build dirs
# =============================================================================

## @brief Normalize a path for Windows workspaces.
## @param[out] out_var Name of the variable to set in the parent scope
##            with the normalized path.
## @param[in] input_path Path to normalize. On WIN32 this will convert
##            forward slashes to backslashes and remove surrounding
##            quotes.
## @note On WIN32 this strips surrounding double quotes (if present)
##       and replaces '/' with '\\' to produce a Windows-style path.
##       On non-WIN32 platforms the input is returned unchanged.
##       Use for values passed to cmd.exe / bat. For paths consumed by
##       CMake itself, prefer normalize_cmake_path().
function(windows_path _out_path _input_path)
	_bm_log_message(CORE LOWLEVEL "Entering windows_path")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL "windows_path requires output variable name and input path")
	endif()

	if(WIN32)
		set(_p "${_input_path}")
		string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
		string(REPLACE "/" "\\" _out "${_p}")
		set(${_out_path} "${_out}" PARENT_SCOPE)
		_bm_log_message(CORE DEBUG "windows_path → ${_out}")
	else()
		set(${_out_path} "${_input_path}" PARENT_SCOPE)
	endif()
	_bm_log_message(CORE LOWLEVEL "Exiting windows_path")
endfunction()

## @brief Normalize a filesystem path for use inside CMake (forward slashes).
## @param[out] _out Name of the variable to set in the parent scope.
## @param[in]  _input Path (may contain backslashes or surrounding quotes).
## @note Strips optional surrounding quotes, then applies file(TO_CMAKE_PATH).
##       Use for ENV-derived paths (BUILDMASTER_DOWNLOADSDIR, cache dirs, etc.)
##       so they are safe in toolchain.cmake and CMake string expansion.
function(normalize_cmake_path _out _input)
	_bm_log_message(CORE LOWLEVEL "Entering normalize_cmake_path")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL "normalize_cmake_path requires output variable name and input path")
	endif()
	set(_p "${_input}")
	string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
	file(TO_CMAKE_PATH "${_p}" _p)
	set(${_out} "${_p}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting normalize_cmake_path")
endfunction()

## @brief Produce a filesystem-safe string from an arbitrary input.
## @param[out] _out Name of the variable to set in the parent scope
##            with the sanitized string.
## @param[in] _input Input string to sanitize.
## @note Replaces any character not in [A-Za-z0-9._-] with '_',
##       collapses repeated underscores to a single '_' and trims
##       leading/trailing underscores.
function(sanitize_for_filename _out _input)
	_bm_log_message(CORE LOWLEVEL "Entering sanitize_for_filename")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL "sanitize_for_filename requires output variable name and input string")
	endif()

	string(REGEX REPLACE "[^A-Za-z0-9._-]" "_" _output "${_input}")
	string(REGEX REPLACE "_+" "_" _output "${_output}")
	string(REGEX REPLACE "^_+|_+$" "" _output "${_output}")

	set(${_out} "${_output}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting sanitize_for_filename")
endfunction()

## @brief Canonical per-component build directory (2.1.x layout).
## @param[out] _out Parent-scope path:
##            `${CMAKE_CURRENT_BINARY_DIR}/bm/<sanitized-id>`.
## @param[in]  _component Component id.
## @note Does not create the directory. `create_component` runs
##       `file(MAKE_DIRECTORY)` on the path it receives.
function(_buildmaster_component_builddir _out _component)
	_bm_log_message(CORE LOWLEVEL "Entering _buildmaster_component_builddir")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL
			"_buildmaster_component_builddir requires output variable and component id")
	endif()
	if("${_component}" STREQUAL "")
		_bm_log_message(CORE FATAL
			"_buildmaster_component_builddir: empty component id")
	endif()
	sanitize_for_filename(_safe "${_component}")
	set(${_out} "${CMAKE_CURRENT_BINARY_DIR}/bm/${_safe}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting _buildmaster_component_builddir")
endfunction()

## @brief Fill a caller variable with a conventional build path.
## @param[out] _out Parent-scope variable name.
## @param[in] _component Optional id. With it:
##            `${CMAKE_CURRENT_BINARY_DIR}/build/<sanitized>/`.
##            Without it: `${CMAKE_CURRENT_BINARY_DIR}/build`.
## @note Does not create the directory. `create_component` does
##       `file(MAKE_DIRECTORY)` on the path it actually uses.
##       Callers that omit the builddir slot get
##       `_buildmaster_component_builddir` instead (`…/bm/<id>`).
function(ensure_build_dir _out)
	_bm_log_message(CORE LOWLEVEL "Entering ensure_build_dir")
	if(ARGC LESS 1)
		_bm_log_message(CORE FATAL "ensure_build_dir requires an output variable name and optional component name")
	endif()

	set(_out_var "${_out}")

	if(ARGC EQUAL 2)
		set(_component "${ARGV1}")
	else()
		set(_component "")
	endif()

	if("${_component}" STREQUAL "")
		set(_sanitized "build")
	else()
		sanitize_for_filename(_sanitized "${_component}")
		set(_sanitized "build/${_sanitized}")
	endif()

	set(_builddir "${CMAKE_CURRENT_BINARY_DIR}/${_sanitized}")
	set(${_out_var} "${_builddir}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting ensure_build_dir")
endfunction()
