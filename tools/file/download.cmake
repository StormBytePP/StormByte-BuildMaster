# tools/file/download.cmake — _bm_file_download / _bm_file_download_cached
# =============================================================================
# Internal. Public surface is FILES={…} on buildmaster_component.
# Each helper creates a CMake custom target of the same name. The generated
# -P script also runs during the caller's configure so the file is on disk
# before nested configure.

## @brief Generate the force-download script and return its path (internal).
## @param[out] out_script Parent-scope path of the generated -P script.
## @param[in]  url        URL to download.
## @param[in]  title      Human-readable title (script filename + messages).
## @param[in]  expected_hash Optional "ALGO=hex" or bare hex.
## @param[in]  max_retries Maximum attempts (default 3).
## @param[in]  current_try Internal try counter (default 1).
## @param[in]  indent_level Status indentation tabs (default 0).
function(_bm_file_generate_download_script out_script url title expected_hash
										max_retries current_try indent_level)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_file_generate_download_script")
	if("${title}" STREQUAL "")
		get_filename_component(title "${url}" NAME)
	endif()
	if("${max_retries}" STREQUAL "")
		set(max_retries 3)
	endif()
	if("${current_try}" STREQUAL "")
		set(current_try 1)
	endif()
	if("${indent_level}" STREQUAL "")
		set(indent_level 0)
	endif()

	string(REPEAT "\t" ${indent_level} _FILE_INDENT)

	get_filename_component(_basename "${url}" NAME)
	_bm_file_validate_no_traversal("${_basename}")
	set(_full_output "${BUILDMASTER_DOWNLOADSDIR}/${_basename}")
	file(MAKE_DIRECTORY "${BUILDMASTER_DOWNLOADSDIR}")

	_bm_path_sanitize(_safe "${title}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/buildmaster_download_${_safe}.cmake")

	set(_FILE_URL           "${url}")
	set(_FILE_OUTPUT        "${_full_output}")
	set(_FILE_TITLE         "${title}")
	set(_FILE_EXPECTED_HASH "${expected_hash}")
	set(_FILE_MAX_RETRIES   "${max_retries}")
	set(_FILE_CURRENT_TRY   "${current_try}")
	set(_FILE_INDENT        "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/templates/file_download.cmake.in"
		"${_script}"
		@ONLY
	)

	set(${out_script} "${_script}" PARENT_SCOPE)
	_bm_log_message(FILE DEBUG "Generated download script ${_script}")
	_bm_log_message(FILE LOWLEVEL "Exiting _bm_file_generate_download_script")
endfunction()

## @brief Create a file target and run its -P script now.
## @param[in] name    Target name.
## @param[in] script  Path to cmake -P script.
## @param[in] comment Progress COMMENT (wrapped with the File log header).
## @param[in] depends Optional list of target dependencies (build-graph only).
## @note `execute_process(-P script)` runs at configure so FILES= can unpack
##       in the same finalize pass. The custom target remains for incremental
##       rebuilds. The script must be idempotent.
function(_bm_file_add_target name script comment)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_file_add_target")
	if(TARGET "${name}")
		_bm_log_message(FILE FATAL
			"file helper: target '${name}' already exists")
	endif()
	if("${comment}" STREQUAL "")
		set(comment "file: ${name}")
	endif()
	if(COMMAND _bm_log_comment)
		_bm_log_comment(_bm_cmt FILE "${comment}")
	else()
		set(_bm_cmt "[BuildMaster/File     ]: ${comment}")
	endif()
	add_custom_target(${name}
		COMMAND ${CMAKE_COMMAND} -P "${script}"
		COMMENT "${_bm_cmt}"
		USES_TERMINAL
		VERBATIM
	)
	if(depends)
		add_dependencies(${name} ${depends})
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_FILE_TARGET_IDS "${name}")
	set_property(GLOBAL PROPERTY BUILDMASTER_FILE_${name}_SCRIPT "${script}")

	execute_process(
		COMMAND ${CMAKE_COMMAND} -P "${script}"
		RESULT_VARIABLE _file_rc
	)
	if(NOT _file_rc EQUAL 0)
		_bm_log_message(FILE FATAL
			"FILES helper '${name}' stopped (exit ${_file_rc}). Read the [BuildMaster/File] FATAL above (hash mismatch, corrupt payload, or network). This line only names the helper that ran at configure.")
	endif()

	_bm_log_message(FILE LOWLEVEL "Exiting _bm_file_add_target")
endfunction()

## @brief Always download a file (retries + optional hash); creates a target.
## @param[in] name Target name (internal FILES slot id).
## @param[in] url  URL to download (basename under BUILDMASTER_DOWNLOADSDIR).
## @param[in] TITLE         Optional human-readable title (default: URL basename).
## @param[in] EXPECTED_HASH Optional "ALGO=hex" or bare hex (SHA256).
## @param[in] MAX_RETRIES   Maximum attempts (default 3).
## @param[in] COMMENT       Optional custom target COMMENT.
## @param[in] DEPENDS       Optional list of CMake targets this waits on.
## @param[in] INDENT        Optional status indent tabs for the generated script.
## @note Not a public command. Callers: `_bm_comp_apply_files` (FORCE).
function(_bm_file_download name url)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_file_download")
	if("${name}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_download: empty name")
	endif()
	if("${url}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_download: empty url")
	endif()

	cmake_parse_arguments(ARG
		""
		"TITLE;EXPECTED_HASH;MAX_RETRIES;COMMENT;INDENT"
		"DEPENDS"
		${ARGN}
	)

	_bm_file_generate_download_script(_script
		"${url}"
		"${ARG_TITLE}"
		"${ARG_EXPECTED_HASH}"
		"${ARG_MAX_RETRIES}"
		"1"
		"${ARG_INDENT}"
	)

	if(NOT ARG_COMMENT)
		if(ARG_TITLE)
			set(ARG_COMMENT "Download ${ARG_TITLE}")
		else()
			set(ARG_COMMENT "Download ${name}")
		endif()
	endif()

	_bm_file_add_target("${name}" "${_script}" "${ARG_COMMENT}"
		"${ARG_DEPENDS}")
	_bm_log_message(FILE DEBUG "_bm_file_download target ${name}")
	_bm_log_message(FILE LOWLEVEL "Exiting _bm_file_download")
endfunction()

## @brief Cache-aware download; creates a target named `name`.
## @param[in] name Target name (internal FILES slot id).
## @param[in] url  URL to download (basename under BUILDMASTER_DOWNLOADSDIR).
## @param[in] TITLE         Optional human-readable title (default: URL basename).
## @param[in] EXPECTED_HASH Optional "ALGO=hex" or bare hex (SHA256).
## @param[in] MAX_RETRIES   Maximum attempts (default 3).
## @param[in] COMMENT       Optional custom target COMMENT.
## @param[in] DEPENDS       Optional list of CMake targets this waits on.
## @param[in] INDENT        Optional status indent tabs for the generated script.
## @note Not a public command. Callers: `_bm_comp_apply_files` (default).
function(_bm_file_download_cached name url)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_file_download_cached")
	if("${name}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_download_cached: empty name")
	endif()
	if("${url}" STREQUAL "")
		_bm_log_message(FILE FATAL "_bm_file_download_cached: empty url")
	endif()

	cmake_parse_arguments(ARG
		""
		"TITLE;EXPECTED_HASH;MAX_RETRIES;COMMENT;INDENT"
		"DEPENDS"
		${ARGN}
	)

	if(NOT ARG_TITLE)
		get_filename_component(ARG_TITLE "${url}" NAME)
	endif()
	if(NOT ARG_MAX_RETRIES)
		set(ARG_MAX_RETRIES 3)
	endif()
	if(NOT ARG_INDENT)
		set(ARG_INDENT 0)
	endif()

	_bm_file_generate_download_script(_force_script
		"${url}"
		"${ARG_TITLE}"
		"${ARG_EXPECTED_HASH}"
		"${ARG_MAX_RETRIES}"
		"1"
		"${ARG_INDENT}"
	)

	get_filename_component(_basename "${url}" NAME)
	_bm_file_validate_no_traversal("${_basename}")
	set(_full_output "${BUILDMASTER_DOWNLOADSDIR}/${_basename}")

	string(REPEAT "\t" ${ARG_INDENT} _FILE_INDENT)
	_bm_path_sanitize(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/buildmaster_download_cached_${_safe}.cmake")

	set(_FILE_URL           "${url}")
	set(_FILE_OUTPUT        "${_full_output}")
	set(_FILE_TITLE         "${ARG_TITLE}")
	set(_FILE_EXPECTED_HASH "${ARG_EXPECTED_HASH}")
	set(_FILE_MAX_RETRIES   "${ARG_MAX_RETRIES}")
	set(_FILE_FORCE_SCRIPT  "${_force_script}")
	set(_FILE_INDENT        "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/templates/file_download_cached.cmake.in"
		"${_script}"
		@ONLY
	)

	if(NOT ARG_COMMENT)
		set(ARG_COMMENT "Download (cached) ${ARG_TITLE}")
	endif()

	_bm_file_add_target("${name}" "${_script}" "${ARG_COMMENT}"
		"${ARG_DEPENDS}")
	_bm_log_message(FILE DEBUG "_bm_file_download_cached target ${name}")
	_bm_log_message(FILE LOWLEVEL "Exiting _bm_file_download_cached")
endfunction()
