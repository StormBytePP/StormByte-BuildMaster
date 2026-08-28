# =============================================================================
# tools/file/decompress.cmake — file_decompress
# =============================================================================

## @brief Decompress an archive into a directory; creates a target named `name`.
## @param[in] name    Target name used with component_dependency / prerequisite.
## @param[in] archive Archive path, or basename under BUILDMASTER_DOWNLOADSDIR.
## @param[in] out_dir Destination directory (created if missing).
## @param[in] TITLE   Optional human-readable title.
## @param[in] COMMENT Optional custom target COMMENT.
## @param[in] DEPENDS Optional list of CMake targets this waits on (e.g. the
##            download target for the same archive). Build-graph only; the
##            extract itself runs during this call.
## @param[in] INDENT  Optional status indent tabs for the generated script.
## @note Uses file(ARCHIVE_EXTRACT) inside the generated -P script.
##       No out-variable / include(). The script runs at configure (so
##       amalgamation sources exist before create_*_component) and again
##       if `name` is built. Call after file_download_cached in the same
##       CMakeLists so the archive is already on disk.
function(file_decompress name archive out_dir)
	buildmaster_message(FILE LOWLEVEL "Entering file_decompress")
	if("${name}" STREQUAL "")
		buildmaster_message(FILE FATAL "file_decompress: empty name")
	endif()
	if("${archive}" STREQUAL "")
		buildmaster_message(FILE FATAL "file_decompress: empty archive")
	endif()
	if("${out_dir}" STREQUAL "")
		buildmaster_message(FILE FATAL "file_decompress: empty out_dir")
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

	_file_validate_no_traversal("${archive}")
	_file_validate_no_traversal("${out_dir}")

	if(IS_ABSOLUTE "${archive}")
		set(_archive "${archive}")
	else()
		set(_archive "${BUILDMASTER_DOWNLOADSDIR}/${archive}")
	endif()

	sanitize_for_filename(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/file_decompress_${_safe}.cmake")

	set(_FILE_ARCHIVE "${_archive}")
	set(_FILE_OUT_DIR "${out_dir}")
	set(_FILE_TITLE   "${ARG_TITLE}")
	set(_FILE_INDENT  "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/file_decompress.cmake.in"
		"${_script}"
		@ONLY
	)

	if(NOT ARG_COMMENT)
		set(ARG_COMMENT "Decompress ${ARG_TITLE}")
	endif()

	_file_add_prerequisite_target("${name}" "${_script}" "${ARG_COMMENT}"
		"${ARG_DEPENDS}")
	buildmaster_message(FILE DEBUG "file_decompress target ${name}")
	buildmaster_message(FILE LOWLEVEL "Exiting file_decompress")
endfunction()
