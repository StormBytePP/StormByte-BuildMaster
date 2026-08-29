# =============================================================================
# library_hints.cmake — shared/static import path helpers
# =============================================================================

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
function(_bm_lib_import_hint _out_var _lib_name _prefix_path)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_lib_import_hint")
	if(ARGC LESS 3 OR ARGC GREATER 4)
		_bm_log_message(CORE FATAL "_bm_lib_import_hint requires output variable name, library name, prefix and optional subdir.")
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
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_lib_import_hint")
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
function(_bm_lib_import_static_hint _out_var _lib_name _prefix_path)
	_bm_log_message(CORE LOWLEVEL "Entering _bm_lib_import_static_hint")
	if(ARGC LESS 3 OR ARGC GREATER 4)
		_bm_log_message(CORE FATAL "_bm_lib_import_static_hint requires output variable name, library name, prefix and optional subdir.")
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
	_bm_log_message(CORE LOWLEVEL "Exiting _bm_lib_import_static_hint")
endfunction()
