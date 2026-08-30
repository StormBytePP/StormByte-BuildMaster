# =============================================================================
# tools/file/decompress.cmake — _bm_file_decompress
# =============================================================================
# Internal. Public surface is FILES={UNPACK} on buildmaster_component.

## @brief Decompress an archive into a directory; creates a target named `name`.
## @param[in] name    Target name (internal FILES slot id + `_unpack`).
## @param[in] archive Archive path, or basename under BUILDMASTER_DOWNLOADSDIR.
## @param[in] out_dir Destination directory (created if missing).
## @param[in] TITLE   Optional human-readable title.
## @param[in] COMMENT Optional custom target COMMENT.
## @param[in] DEPENDS Optional list of CMake targets this waits on.
## @param[in] INDENT  Optional status indent tabs for the generated script.
## @note Uses file(ARCHIVE_EXTRACT) inside the generated -P script.
##       The script runs at configure (so SOURCE trees exist before nested
##       setup) and again if `name` is built. Not a public command.
function(_bm_file_decompress name archive out_dir)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_file_decompress")
	if("${name}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_decompress: empty name")
	endif()
	if("${archive}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_decompress: empty archive")
	endif()
	if("${out_dir}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_decompress: empty out_dir")
	endif()

	cmake_parse_arguments(ARG
		""
		"TITLE;COMMENT;INDENT"
		"DEPENDS"
		${ARGN}
	)

	if(NOT ARG_TITLE)
		get_filename_component(ARG_TITLE "${archive}" NAME)
	endif()
	if(NOT ARG_INDENT)
		set(ARG_INDENT 0)
	endif()

	string(REPEAT "\t" ${ARG_INDENT} _FILE_INDENT)

	_bm_file_validate_no_traversal("${archive}")
	_bm_file_validate_no_traversal("${out_dir}")

	if(IS_ABSOLUTE "${archive}")
		set(_archive "${archive}")
	else()
		set(_archive "${BUILDMASTER_DOWNLOADSDIR}/${archive}")
	endif()

	_bm_path_sanitize(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/buildmaster_decompress_${_safe}.cmake")

	set(_FILE_ARCHIVE "${_archive}")
	set(_FILE_OUT_DIR "${out_dir}")
	set(_FILE_TITLE   "${ARG_TITLE}")
	set(_FILE_INDENT  "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/templates/file_decompress.cmake.in"
		"${_script}"
		@ONLY
	)

	if(NOT ARG_COMMENT)
		set(ARG_COMMENT "Decompress ${ARG_TITLE}")
	endif()

	_bm_file_add_target("${name}" "${_script}" "${ARG_COMMENT}"
		"${ARG_DEPENDS}")
	_bm_log_message(FILE DEBUG "_bm_file_decompress target ${name}")
	_bm_log_message(FILE LOWLEVEL "Exiting _bm_file_decompress")
endfunction()
