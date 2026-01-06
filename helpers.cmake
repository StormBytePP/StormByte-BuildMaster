## @brief Normalize a path for Windows workspaces.
## @param[out] out_var Name of the variable to set in the parent scope
##            with the normalized path.
## @param[in] input_path Path to normalize. On WIN32 this will convert
##            forward slashes to backslashes and remove surrounding
##            quotes.
## @note On WIN32 this strips surrounding double quotes (if present)
##       and replaces '/' with '\\' to produce a Windows-style path.
##       On non-WIN32 platforms the input is returned unchanged.
function(windows_path _out_path _input_path )
	if(NOT ARGC EQUAL 2)
		message(FATAL_ERROR "windows_path requires output variable name and input path")
	endif()

	if(WIN32)
		# Minimal normalization: strip surrounding quotes and replace '/' with '\\'
		set(_p "${_input_path}")
		string(REGEX REPLACE "^\"(.*)\"$" "\\1" _p "${_p}")
		string(REPLACE "/" "\\" _out "${_p}")
		set(${_out_path} "${_out}" PARENT_SCOPE)
	else()
		set(${_out_path} "${_input_path}" PARENT_SCOPE)
	endif()
endfunction()

## @brief Construct a platform-appropriate shared-library filename hint.
## @param[out] out_var Variable name to set in the parent scope with the
##            constructed name.
## @param[in] lib_name Base library name without prefix/suffix (for
##            example: avcodec).
## @param[in] prefix_path Optional directory prefix to prepend before the
##            library filename (no trailing separator expected).
## @note On WIN32 uses `CMAKE_IMPORT_LIBRARY_PREFIX`/
##       `CMAKE_IMPORT_LIBRARY_SUFFIX` and backslash separators. On
##       other platforms uses shared library prefix/suffix and '/'. When
##       `prefix_path` is provided it is prepended before the platform
##       prefix.
function(library_import_hint _out_var _lib_name _prefix_path)
	if(NOT ARGC EQUAL 3)
		message(FATAL_ERROR "library_import_hint requires output variable name, library name and prefix.")
	endif()

	if (WIN32)
		set(_prefix "${CMAKE_IMPORT_LIBRARY_PREFIX}")
		set(_suffix "${CMAKE_IMPORT_LIBRARY_SUFFIX}")
	else()
		set(_prefix "${CMAKE_SHARED_LIBRARY_PREFIX}")
		set(_suffix "${CMAKE_SHARED_LIBRARY_SUFFIX}")
	endif()

	if(NOT _prefix_path STREQUAL "")
		set(_prefix "${_prefix_path}/${_prefix}")
	endif()
	
	set(${_out_var} "${_prefix}${_lib_name}${_suffix}" PARENT_SCOPE)
endfunction()

## @brief Construct a static-library filename hint for importing/linking.
## @param[out] out_var Variable name to set in the parent scope with the
##            constructed name.
## @param[in] lib_name Base library name without prefix/suffix.
## @param[in] prefix_path Optional directory prefix to prepend before the
##            library filename (no trailing separator expected).
## @note Uses `CMAKE_STATIC_LIBRARY_PREFIX` and
##       `CMAKE_STATIC_LIBRARY_SUFFIX`. If `prefix_path` is provided it
##       is prepended with a '/' separator.
function(library_import_static_hint _out_var _lib_name _prefix_path)
	if(NOT ARGC EQUAL 3)
		message(FATAL_ERROR "library_import_static_hint requires output variable name, library name and prefix.")
	endif()

	set(_separator "/")

	if(NOT _prefix_path STREQUAL "")
		set(_prefix "${_prefix_path}${_separator}${CMAKE_STATIC_LIBRARY_PREFIX}")
	else()
		set(_prefix "${CMAKE_STATIC_LIBRARY_PREFIX}")
	endif()
	
	set(${_out_var} "${_prefix}${_lib_name}${CMAKE_STATIC_LIBRARY_SUFFIX}" PARENT_SCOPE)
endfunction()

## @brief Produce a filesystem-safe string from an arbitrary input.
## @param[out] _out Name of the variable to set in the parent scope
##            with the sanitized string.
## @param[in] _input Input string to sanitize.
## @note Replaces any character not in [A-Za-z0-9._-] with '_',
##       collapses repeated underscores to a single '_' and trims
##       leading/trailing underscores.
##
function(sanitize_for_filename _out _input)
	if(NOT ARGC EQUAL 2)
		message(FATAL_ERROR "sanitize_for_filename requires output variable name and input string")
	endif()

	# Sanitize component name for safe filenames:
	# - replace any character not in [A-Za-z0-9._-] with '_'
	# - collapse repeated underscores
	# - trim leading/trailing underscores
	string(REGEX REPLACE "[^A-Za-z0-9._-]" "_" _output "${_input}")
	string(REGEX REPLACE "_+" "_" _output "${_output}")
	string(REGEX REPLACE "^_+|_+$" "" _output "${_output}")

	set(${_out} "${_output}" PARENT_SCOPE)
endfunction()

## @brief Toggle a boolean-style variable between TRUE and FALSE in the
##        parent scope.
## @param[in] var_name Name of the variable to toggle; the current value
##            is read and the negated value is written into the parent
##            scope.
function(toggle_bool _var)
	if(NOT ARGC EQUAL 1)
		message(FATAL_ERROR "toggle_bool requires one variable name")
	endif()

	if(${${_var}})
		set(${_var} FALSE PARENT_SCOPE)
	else()
		set(${_var} TRUE PARENT_SCOPE)
	endif()
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
##
function(list_join _out_var _raw_string _separator)
	set(result "\"")
	set(in_single_quote FALSE)
	set(in_double_quote FALSE)

	set(raw "${_raw_string}")

	if(NOT "${raw}" STREQUAL "")
		string(LENGTH "${raw}" N)
		math(EXPR N "${N} - 1")

		foreach(i RANGE ${N})
			string(SUBSTRING "${raw}" ${i} 1 ch)

			# Detect opening/closing quotes — but DO NOT output them
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

			# Replace semicolon only when NOT inside quotes
			if(ch STREQUAL ";")
				if(NOT in_single_quote AND NOT in_double_quote)
					set(ch "\"${_separator}\"")
				else()
					set(ch ";")
				endif()
			endif()

			# Append the character
			set(result "${result}${ch}")
		endforeach()
	endif()

	set(result "${result}\"")
	set(${_out_var} "${result}" PARENT_SCOPE)
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
##
function(ensure_build_dir _out)
	if(ARGC LESS 1)
		message(FATAL_ERROR "ensure_build_dir requires an output variable name and optional component name")
	endif()

	set(_out_var "${_out}")

	# Join any additional args into a single component string
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
endfunction()

# A convenience files to add all bootstrap helper functions
include(${BUILDMASTER_SRCDIR}/env/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/cmake/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/git/helpers.cmake)
include(${BUILDMASTER_SRCDIR}/tools/meson/helpers.cmake)
# Component helpers need to be included after tools so cmake and
# meson helpers are available
include(${BUILDMASTER_SRCDIR}/component/helpers.cmake)