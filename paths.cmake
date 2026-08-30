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
##       CMake itself, prefer _bm_path_normalize().
function(_bm_path_windows _out_path _input_path)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_path_windows")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL "_bm_path_windows requires output variable name and input path")
	endif()

	if(WIN32)
		set(_p "${_input_path}")
		string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
		string(REPLACE "/" "\\" _out "${_p}")
		set(${_out_path} "${_out}" PARENT_SCOPE)
		_bm_log_message(CORE DEBUG "_bm_path_windows → ${_out}")
	else()
		set(${_out_path} "${_input_path}" PARENT_SCOPE)
	endif()
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_path_windows")
endfunction()

## @brief Normalize a filesystem path for use inside CMake (forward slashes).
## @param[out] _out Name of the variable to set in the parent scope.
## @param[in]  _input Path (may contain backslashes or surrounding quotes).
## @note Strips optional surrounding quotes, then applies file(TO_CMAKE_PATH).
##       Use for ENV-derived paths (BUILDMASTER_DOWNLOADSDIR, cache dirs, etc.)
##       so they are safe in toolchain.cmake and CMake string expansion.
##       Does not quote spaces; those belong in `_bm_path_compile_include`.
function(_bm_path_normalize _out _input)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_path_normalize")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL "_bm_path_normalize requires output variable name and input path")
	endif()
	set(_p "${_input}")
	string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
	file(TO_CMAKE_PATH "${_p}" _p)
	set(${_out} "${_p}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_path_normalize")
endfunction()

## @brief One compile-flag token `-I<path>` safe for CMake and Meson.
## @param[out] _out Parent-scope token (single list element).
## @param[in]  _input Directory to include.
## @note Normalizes with `_bm_path_normalize` first (`/` so `\Users` is not
##       eaten as `\U`). The path is not wrapped in quotes. Spaces stay
##       inside this one list item. Empty input is FATAL.
function(_bm_path_compile_include _out _input)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_path_compile_include")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL
			"_bm_path_compile_include requires output variable and path")
	endif()
	if("${_input}" STREQUAL "")
		_bm_log_message(CORE FATAL
			"_bm_path_compile_include: empty path")
	endif()
	_bm_path_normalize(_p "${_input}")
	set(${_out} "-I${_p}" PARENT_SCOPE)
	_bm_log_message(CORE DEBUG "_bm_path_compile_include → -I${_p}")
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_path_compile_include")
endfunction()

## @brief Produce a filesystem-safe string from an arbitrary input.
## @param[out] _out Name of the variable to set in the parent scope
##            with the sanitized string.
## @param[in] _input Input string to sanitize.
## @note Replaces any character not in [A-Za-z0-9._-] with '_',
##       collapses repeated underscores to a single '_' and trims
##       leading/trailing underscores.
function(_bm_path_sanitize _out _input)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_path_sanitize")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL "_bm_path_sanitize requires output variable name and input string")
	endif()

	string(REGEX REPLACE "[^A-Za-z0-9._-]" "_" _output "${_input}")
	string(REGEX REPLACE "_+" "_" _output "${_output}")
	string(REGEX REPLACE "^_+|_+$" "" _output "${_output}")

	set(${_out} "${_output}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_path_sanitize")
endfunction()

## @brief Canonical per-component build directory.
## @param[out] _out Parent-scope path:
##            `${CMAKE_CURRENT_BINARY_DIR}/bm/<sanitized-id>`.
## @param[in]  _component Component id.
## @note Does not create the directory. `_bm_graph_create` runs
##       `file(MAKE_DIRECTORY)` on this path.
function(_bm_path_component_builddir _out _component)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_path_component_builddir")
	if(NOT ARGC EQUAL 2)
		_bm_log_message(CORE FATAL
			"_bm_path_component_builddir requires output variable and component id")
	endif()
	if("${_component}" STREQUAL "")
		_bm_log_message(CORE FATAL
			"_bm_path_component_builddir: empty component id")
	endif()
	_bm_path_sanitize(_safe "${_component}")
	set(${_out} "${CMAKE_CURRENT_BINARY_DIR}/bm/${_safe}" PARENT_SCOPE)
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_path_component_builddir")
endfunction()
