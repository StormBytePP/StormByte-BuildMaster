include("${CMAKE_CURRENT_LIST_DIR}/log.cmake")

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
	buildmaster_message(CORE LOWLEVEL "Entering windows_path")
	if(NOT ARGC EQUAL 2)
		buildmaster_message(CORE FATAL "windows_path requires output variable name and input path")
	endif()

	if(WIN32)
		set(_p "${_input_path}")
		string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
		string(REPLACE "/" "\\" _out "${_p}")
		set(${_out_path} "${_out}" PARENT_SCOPE)
		buildmaster_message(CORE DEBUG "windows_path → ${_out}")
	else()
		set(${_out_path} "${_input_path}" PARENT_SCOPE)
	endif()
	buildmaster_message(CORE LOWLEVEL "Exiting windows_path")
endfunction()

## @brief Normalize a filesystem path for use inside CMake (forward slashes).
## @param[out] _out Name of the variable to set in the parent scope.
## @param[in]  _input Path (may contain backslashes or surrounding quotes).
## @note Strips optional surrounding quotes, then applies file(TO_CMAKE_PATH).
##       Use for ENV-derived paths (BUILDMASTER_DOWNLOADSDIR, cache dirs, etc.)
##       so they are safe in toolchain.cmake and CMake string expansion.
function(normalize_cmake_path _out _input)
	buildmaster_message(CORE LOWLEVEL "Entering normalize_cmake_path")
	if(NOT ARGC EQUAL 2)
		buildmaster_message(CORE FATAL "normalize_cmake_path requires output variable name and input path")
	endif()
	set(_p "${_input}")
	string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
	file(TO_CMAKE_PATH "${_p}" _p)
	set(${_out} "${_p}" PARENT_SCOPE)
	buildmaster_message(CORE LOWLEVEL "normalize_cmake_path → ${_p}")
	buildmaster_message(CORE LOWLEVEL "Exiting normalize_cmake_path")
endfunction()

## @brief Construct a platform-appropriate shared-library filename hint.
## @param[out] out_var Variable name to set in the parent scope with the
##            constructed name.
## @param[in] lib_name Base library name without prefix/suffix (for
##            example: avcodec).
## @param[in] prefix_path Optional directory prefix to prepend before the
##            library filename (no trailing separator expected).
## @param[in] subdir Optional (4th argument) subdirectory relative to
##            `prefix_path` (for example `recursive/cmake`). Empty or
##            omitted keeps the legacy layout under `prefix_path` itself.
## @note On WIN32 uses `CMAKE_IMPORT_LIBRARY_PREFIX`/
##       `CMAKE_IMPORT_LIBRARY_SUFFIX` and '/' separators. On
##       other platforms uses shared library prefix/suffix and '/'. When
##       `prefix_path` is provided it is prepended before the platform
##       prefix. `subdir` is inserted between `prefix_path` and the
##       filename when non-empty.
function(library_import_hint _out_var _lib_name _prefix_path)
	buildmaster_message(CORE LOWLEVEL "Entering library_import_hint")
	if(ARGC LESS 3 OR ARGC GREATER 4)
		buildmaster_message(CORE FATAL "library_import_hint requires output variable name, library name, prefix and optional subdir.")
	endif()

	set(_subdir "")
	if(ARGC EQUAL 4)
		set(_subdir "${ARGV3}")
	endif()

	if(WIN32)
		set(_pfx "${CMAKE_IMPORT_LIBRARY_PREFIX}")
		set(_suffix "${CMAKE_IMPORT_LIBRARY_SUFFIX}")
	else()
		set(_pfx "${CMAKE_SHARED_LIBRARY_PREFIX}")
		set(_suffix "${CMAKE_SHARED_LIBRARY_SUFFIX}")
	endif()

	set(_base "${_prefix_path}")
	if(NOT _subdir STREQUAL "")
		if(NOT _base STREQUAL "")
			set(_base "${_base}/${_subdir}")
		else()
			set(_base "${_subdir}")
		endif()
	endif()

	if(NOT _base STREQUAL "")
		set(_pfx "${_base}/${_pfx}")
	endif()

	set(${_out_var} "${_pfx}${_lib_name}${_suffix}" PARENT_SCOPE)
	buildmaster_message(CORE LOWLEVEL "library_import_hint → ${_pfx}${_lib_name}${_suffix}")
	buildmaster_message(CORE LOWLEVEL "Exiting library_import_hint")
endfunction()

## @brief Construct a static-library filename hint for importing/linking.
## @param[out] out_var Variable name to set in the parent scope with the
##            constructed name.
## @param[in] lib_name Base library name without prefix/suffix.
## @param[in] prefix_path Optional directory prefix to prepend before the
##            library filename (no trailing separator expected).
## @param[in] subdir Optional (4th argument) subdirectory relative to
##            `prefix_path` (for example `recursive/cmake`). Empty or
##            omitted keeps the legacy layout under `prefix_path` itself.
## @note Uses `CMAKE_STATIC_LIBRARY_PREFIX` and
##       `CMAKE_STATIC_LIBRARY_SUFFIX`. If `prefix_path` is provided it
##       is prepended with a '/' separator. `subdir` is inserted between
##       `prefix_path` and the filename when non-empty.
function(library_import_static_hint _out_var _lib_name _prefix_path)
	buildmaster_message(CORE LOWLEVEL "Entering library_import_static_hint")
	if(ARGC LESS 3 OR ARGC GREATER 4)
		buildmaster_message(CORE FATAL "library_import_static_hint requires output variable name, library name, prefix and optional subdir.")
	endif()

	set(_subdir "")
	if(ARGC EQUAL 4)
		set(_subdir "${ARGV3}")
	endif()

	set(_separator "/")

	set(_base "${_prefix_path}")
	if(NOT _subdir STREQUAL "")
		if(NOT _base STREQUAL "")
			set(_base "${_base}${_separator}${_subdir}")
		else()
			set(_base "${_subdir}")
		endif()
	endif()

	if(NOT _base STREQUAL "")
		set(_prefix "${_base}${_separator}${CMAKE_STATIC_LIBRARY_PREFIX}")
	else()
		set(_prefix "${CMAKE_STATIC_LIBRARY_PREFIX}")
	endif()

	set(${_out_var} "${_prefix}${_lib_name}${CMAKE_STATIC_LIBRARY_SUFFIX}" PARENT_SCOPE)
	buildmaster_message(CORE LOWLEVEL "library_import_static_hint → ${_prefix}${_lib_name}${CMAKE_STATIC_LIBRARY_SUFFIX}")
	buildmaster_message(CORE LOWLEVEL "Exiting library_import_static_hint")
endfunction()

## @brief Produce a filesystem-safe string from an arbitrary input.
## @param[out] _out Name of the variable to set in the parent scope
##            with the sanitized string.
## @param[in] _input Input string to sanitize.
## @note Replaces any character not in [A-Za-z0-9._-] with '_',
##       collapses repeated underscores to a single '_' and trims
##       leading/trailing underscores.
function(sanitize_for_filename _out _input)
	buildmaster_message(CORE LOWLEVEL "Entering sanitize_for_filename")
	if(NOT ARGC EQUAL 2)
		buildmaster_message(CORE FATAL "sanitize_for_filename requires output variable name and input string")
	endif()

	string(REGEX REPLACE "[^A-Za-z0-9._-]" "_" _output "${_input}")
	string(REGEX REPLACE "_+" "_" _output "${_output}")
	string(REGEX REPLACE "^_+|_+$" "" _output "${_output}")

	set(${_out} "${_output}" PARENT_SCOPE)
	buildmaster_message(CORE LOWLEVEL "sanitize_for_filename → ${_output}")
	buildmaster_message(CORE LOWLEVEL "Exiting sanitize_for_filename")
endfunction()

## @brief Toggle a boolean-style variable between TRUE and FALSE in the
##        parent scope.
## @param[in] var_name Name of the variable to toggle; the current value
##            is read and the negated value is written into the parent
##            scope.
function(toggle_bool _var)
	buildmaster_message(CORE LOWLEVEL "Entering toggle_bool")
	if(NOT ARGC EQUAL 1)
		buildmaster_message(CORE FATAL "toggle_bool requires one variable name")
	endif()

	if(${${_var}})
		set(${_var} FALSE PARENT_SCOPE)
	else()
		set(${_var} TRUE PARENT_SCOPE)
	endif()
	buildmaster_message(CORE LOWLEVEL "Exiting toggle_bool")
endfunction()

## @brief Join a CMake list into a single string while preserving
##        semicolons inside quoted substrings.
## @param[out] _out_var Name of the variable to set in the parent scope
##            with the resulting joined string.
## @param[in] _list_var Name of a variable that contains a CMake list
##            (pass the variable name, not a literal list).
## @param[in] _separator String used to replace top-level semicolons
##            (those not inside quotes).
## @param[in] preserve_quotes Optional boolean (TRUE/FALSE, default
##            TRUE). If TRUE single and double quotes are preserved in
##            the output; if FALSE quotes are removed.
## @note Iterates the serialized list character-by-character tracking
##       quote state; replaces semicolons only when not inside quotes
##       and escapes semicolons inside quotes so they remain part of
##       list elements. Does not validate matching quotes; unbalanced
##       quotes may produce unexpected output.
function(list_join _out_var _raw_string _separator)
	buildmaster_message(CORE LOWLEVEL "Entering list_join")
	set(result "\"")
	set(in_single_quote FALSE)
	set(in_double_quote FALSE)

	set(raw "${_raw_string}")

	if(NOT "${raw}" STREQUAL "")
		string(LENGTH "${raw}" N)
		math(EXPR N "${N} - 1")

		foreach(i RANGE ${N})
			string(SUBSTRING "${raw}" ${i} 1 ch)

			if(ch STREQUAL "'")
				if(NOT in_double_quote)
					toggle_bool(in_single_quote)
				endif()
				continue()
			endif()

			if(ch STREQUAL "\"")
				if(NOT in_single_quote)
					toggle_bool(in_double_quote)
				endif()
				continue()
			endif()

			if(ch STREQUAL ";")
				if(NOT in_single_quote AND NOT in_double_quote)
					set(ch "\"${_separator}\"")
				else()
					set(ch ";")
				endif()
			endif()

			set(result "${result}${ch}")
		endforeach()
	endif()

	set(result "${result}\"")
	set(${_out_var} "${result}" PARENT_SCOPE)
	buildmaster_message(CORE LOWLEVEL "Exiting list_join")
endfunction()

## @brief Ensure a per-component build directory exists and return its
##        path.
## @param[out] _out Name of the variable to set in the parent scope with
##            the created directory path.
## @param[in] _component Optional component name; when provided the
##            directory will be `${CMAKE_CURRENT_BINARY_DIR}/<sanitized>/`
##            where `<sanitized>` is produced by
##            `sanitize_for_filename`.
## @note Creates the directory with `file(MAKE_DIRECTORY ...)` if it
##       does not already exist.
function(ensure_build_dir _out)
	buildmaster_message(CORE LOWLEVEL "Entering ensure_build_dir")
	if(ARGC LESS 1)
		buildmaster_message(CORE FATAL "ensure_build_dir requires an output variable name and optional component name")
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
	file(MAKE_DIRECTORY "${_builddir}")
	set(${_out_var} "${_builddir}" PARENT_SCOPE)
	buildmaster_message(CORE LOWLEVEL "ensure_build_dir → ${_builddir}")
	buildmaster_message(CORE LOWLEVEL "Exiting ensure_build_dir")
endfunction()

# Toolchain helpers first so create_* stages can validate/resolve profiles
include(${BUILDMASTER_SRCDIR}/toolchain/helpers.cmake)

include(${BUILDMASTER_SRCDIR}/env/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/cmake/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/file/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/git/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/meson/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/archive/helpers.cmake)
# Component helpers need to be included after tools so cmake and
# meson helpers are available
include(${BUILDMASTER_SRCDIR}/component/helpers.cmake)
