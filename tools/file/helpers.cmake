# =============================================================================
# tools/file/helpers.cmake
# =============================================================================
# Helpers for downloading and decompressing files in a portable, deterministic
# and user-friendly way (configure-time or build-time via generated scripts).
# =============================================================================

# Recommended downloads directory (created if missing)
if(NOT DEFINED BUILDMASTER_DOWNLOADSDIR)
	set(BUILDMASTER_DOWNLOADSDIR "${BUILDMASTER_BINDIR}/downloads")
	file(MAKE_DIRECTORY "${BUILDMASTER_DOWNLOADSDIR}")
endif()

# Scripts directory for this module
if(NOT DEFINED BUILDMASTER_SCRIPTS_FILE_DIR)
	set(BUILDMASTER_SCRIPTS_FILE_DIR "${BUILDMASTER_SCRIPTSDIR}/file")
	file(MAKE_DIRECTORY "${BUILDMASTER_SCRIPTS_FILE_DIR}")
endif()

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

## @brief Validate that a path does not contain path-traversal sequences.
## @param[in] _path Path to validate.
## @note Emits FATAL_ERROR if the path contains ".." anywhere.
function(_file_validate_no_traversal _path)
	if("${_path}" MATCHES "\\.\\.")
		message(FATAL_ERROR
			"Path traversal detected (contains '..'):\n  ${_path}\n"
			"Refusing to continue for security reasons."
		)
	endif()
endfunction()

## @brief Check whether a file matches an expected checksum.
## @param[out] _result Parent-scope variable that receives TRUE or FALSE.
## @param[in]  _file   Full path to the file to check.
## @param[in]  _hash   Expected hash in the form "ALGO=value" (e.g. "SHA256=abc...").
##                     If empty, the function returns FALSE.
## @note Performs no output messages. Supports any algorithm accepted by
##       file(<ALGO>).
function(file_checksum_correct _result _file _hash)
	if("${_hash}" STREQUAL "")
		set(${_result} FALSE PARENT_SCOPE)
		return()
	endif()

	if(NOT EXISTS "${_file}")
		set(${_result} FALSE PARENT_SCOPE)
		return()
	endif()

	# Parse ALGO=value
	string(REGEX REPLACE "^([A-Za-z0-9]+)=(.*)$" "\\1;\\2" _parts "${_hash}")
	list(LENGTH _parts _len)
	if(NOT _len EQUAL 2)
		set(${_result} FALSE PARENT_SCOPE)
		return()
	endif()

	list(GET _parts 0 _algo)
	list(GET _parts 1 _expected)

	string(TOUPPER "${_algo}" _algo)

	file(${_algo} "${_file}" _actual)
	if(_actual STREQUAL _expected)
		set(${_result} TRUE PARENT_SCOPE)
	else()
		set(${_result} FALSE PARENT_SCOPE)
	endif()
endfunction()

# -----------------------------------------------------------------------------
# file_download – always forces a download (with retries)
# -----------------------------------------------------------------------------

## @brief Generate a CMake script that always downloads a file (with retries
##        and optional hash verification).
## @param[out] _out_var          Parent-scope variable that receives the full
##                               path of the generated script.
## @param[in]  _url              URL to download.
## @param[in]  TITLE             Optional human-readable title used in messages
##                               and for the script filename.
## @param[in]  EXPECTED_HASH     Optional "ALGO=value" (e.g. "SHA256=...").
## @param[in]  MAX_RETRIES       Maximum number of attempts (default 3).
## @param[in]  CURRENT_TRY       Internal counter used for recursion (default 1).
## @param[in]  indent_level      Optional indentation level (number of tabs)
##                               for status messages (same style as create_component).
## @note The file is always saved under ${BUILDMASTER_DOWNLOADSDIR}/ using the
##       basename of the URL. No destination path is accepted from the caller.
##       The generated script uses cmake -E echo_append so the user sees
##       activity immediately. Downloads are silent (no SHOW_PROGRESS).
function(file_download _out_var _url)
	cmake_parse_arguments(PARSE_ARGV 2
		ARG
		""
		"TITLE;EXPECTED_HASH;MAX_RETRIES;CURRENT_TRY"
		""
	)

	# Optional indent level (last positional argument)
	if(ARGC GREATER 2)
		list(LENGTH ARGV _argc)
		math(EXPR _last_idx "${_argc} - 1")
		list(GET ARGV ${_last_idx} _maybe_indent)
		if(_maybe_indent MATCHES "^[0-9]+$")
			set(_indent_level "${_maybe_indent}")
		else()
			set(_indent_level 0)
		endif()
	else()
		set(_indent_level 0)
	endif()

	string(REPEAT "\t" ${_indent_level} _FILE_INDENT)

	# Defaults
	if(NOT ARG_TITLE)
		get_filename_component(ARG_TITLE "${_url}" NAME)
	endif()
	if(NOT ARG_MAX_RETRIES)
		set(ARG_MAX_RETRIES 3)
	endif()
	if(NOT ARG_CURRENT_TRY)
		set(ARG_CURRENT_TRY 1)
	endif()
	if(NOT ARG_EXPECTED_HASH)
		set(ARG_EXPECTED_HASH "")
	endif()

	# Destination is always under DOWNLOADSDIR + basename of the URL
	get_filename_component(_basename "${_url}" NAME)
	_file_validate_no_traversal("${_basename}")
	set(_full_output "${BUILDMASTER_DOWNLOADSDIR}/${_basename}")

	# Ensure parent directory exists
	file(MAKE_DIRECTORY "${BUILDMASTER_DOWNLOADSDIR}")

	# Script path
	sanitize_for_filename(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/file_download_${_safe}.cmake")

	# Template variables
	set(_FILE_URL            "${_url}")
	set(_FILE_OUTPUT         "${_full_output}")
	set(_FILE_TITLE          "${ARG_TITLE}")
	set(_FILE_EXPECTED_HASH  "${ARG_EXPECTED_HASH}")
	set(_FILE_MAX_RETRIES    "${ARG_MAX_RETRIES}")
	set(_FILE_CURRENT_TRY    "${ARG_CURRENT_TRY}")
	set(_FILE_INDENT         "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/file_download.cmake.in"
		"${_script}"
		@ONLY
	)

	set(${_out_var} "${_script}" PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# file_download_cached – prefer cache, fall back to force download
# -----------------------------------------------------------------------------

## @brief Generate a CMake script that downloads a file only when necessary
##        (cache-aware). Also generates the underlying force-download script.
## @param[out] _out_var          Parent-scope variable that receives the full
##                               path of the *cached* script.
## @param[in]  _url              URL to download.
## @param[in]  TITLE             Optional human-readable title.
## @param[in]  EXPECTED_HASH     Optional "ALGO=value".
## @param[in]  MAX_RETRIES       Maximum number of attempts (default 3).
## @param[in]  indent_level      Optional indentation level.
## @note The file is always saved under ${BUILDMASTER_DOWNLOADSDIR}/ using the
##       basename of the URL. No destination path is accepted from the caller.
##       This function generates *two* scripts:
##       1. file_download_<safe>.cmake
##       2. file_download_cached_<safe>.cmake (the one returned)
function(file_download_cached _out_var _url)
	cmake_parse_arguments(PARSE_ARGV 2
		ARG
		""
		"TITLE;EXPECTED_HASH;MAX_RETRIES"
		""
	)

	# Optional indent
	if(ARGC GREATER 2)
		list(LENGTH ARGV _argc)
		math(EXPR _last_idx "${_argc} - 1")
		list(GET ARGV ${_last_idx} _maybe_indent)
		if(_maybe_indent MATCHES "^[0-9]+$")
			set(_indent_level "${_maybe_indent}")
		else()
			set(_indent_level 0)
		endif()
	else()
		set(_indent_level 0)
	endif()

	string(REPEAT "\t" ${_indent_level} _FILE_INDENT)

	if(NOT ARG_TITLE)
		get_filename_component(ARG_TITLE "${_url}" NAME)
	endif()
	if(NOT ARG_MAX_RETRIES)
		set(ARG_MAX_RETRIES 3)
	endif()
	if(NOT ARG_EXPECTED_HASH)
		set(ARG_EXPECTED_HASH "")
	endif()

	# Destination is always under DOWNLOADSDIR + basename of the URL
	get_filename_component(_basename "${_url}" NAME)
	_file_validate_no_traversal("${_basename}")
	set(_full_output "${BUILDMASTER_DOWNLOADSDIR}/${_basename}")

	# 1. Always generate the force-download script first
	file_download(_force_script
		"${_url}"
		TITLE "${ARG_TITLE}"
		EXPECTED_HASH "${ARG_EXPECTED_HASH}"
		MAX_RETRIES "${ARG_MAX_RETRIES}"
		CURRENT_TRY 1
		${_indent_level}
	)

	# 2. Generate the cached wrapper
	sanitize_for_filename(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/file_download_cached_${_safe}.cmake")

	set(_FILE_URL            "${_url}")
	set(_FILE_OUTPUT         "${_full_output}")
	set(_FILE_TITLE          "${ARG_TITLE}")
	set(_FILE_EXPECTED_HASH  "${ARG_EXPECTED_HASH}")
	set(_FILE_MAX_RETRIES    "${ARG_MAX_RETRIES}")
	set(_FILE_FORCE_SCRIPT   "${_force_script}")
	set(_FILE_INDENT         "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/file_download_cached.cmake.in"
		"${_script}"
		@ONLY
	)

	set(${_out_var} "${_script}" PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# file_decompress
# -----------------------------------------------------------------------------

## @brief Generate a CMake script that decompresses an archive into a directory.
## @param[out] _out_var     Parent-scope variable that receives the script path.
## @param[in]  _file        Full path to the archive file (or relative name under DOWNLOADSDIR).
## @param[in]  _out_dir     Destination directory (created if missing).
## @param[in]  TITLE        Optional human-readable title.
## @param[in]  indent_level Optional indentation level.
## @note Uses the native file(ARCHIVE_EXTRACT) command (CMake ≥ 3.18).
function(file_decompress _out_var _file _out_dir)
	cmake_parse_arguments(PARSE_ARGV 3
		ARG
		""
		"TITLE"
		""
	)

	# Optional indent
	if(ARGC GREATER 3)
		list(LENGTH ARGV _argc)
		math(EXPR _last_idx "${_argc} - 1")
		list(GET ARGV ${_last_idx} _maybe_indent)
		if(_maybe_indent MATCHES "^[0-9]+$")
			set(_indent_level "${_maybe_indent}")
		else()
			set(_indent_level 0)
		endif()
	else()
		set(_indent_level 0)
	endif()

	string(REPEAT "\t" ${_indent_level} _FILE_INDENT)

	if(NOT ARG_TITLE)
		get_filename_component(ARG_TITLE "${_file}" NAME)
	endif()

	_file_validate_no_traversal("${_file}")
	_file_validate_no_traversal("${_out_dir}")

	# If the given file is not absolute, assume it lives under DOWNLOADSDIR
	if(IS_ABSOLUTE "${_file}")
		set(_archive "${_file}")
	else()
		set(_archive "${BUILDMASTER_DOWNLOADSDIR}/${_file}")
	endif()

	sanitize_for_filename(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/file_decompress_${_safe}.cmake")

	set(_FILE_ARCHIVE   "${_archive}")
	set(_FILE_OUT_DIR   "${_out_dir}")
	set(_FILE_TITLE     "${ARG_TITLE}")
	set(_FILE_INDENT    "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/file_decompress.cmake.in"
		"${_script}"
		@ONLY
	)

	set(${_out_var} "${_script}" PARENT_SCOPE)
endfunction()