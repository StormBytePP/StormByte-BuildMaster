# =============================================================================
# tools/file/helpers.cmake
# =============================================================================
# Declarative download / decompress helpers.
# Each public call creates a CMake custom target of the same name (no out-var,
# no include()). Wire with:
#   component_dependency(<component> <file_target>)
# =============================================================================

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
## @param[in]  _hash   Expected hash. Accepted forms:
##                       - empty                    → always FALSE (caller should skip)
##                       - "ALGO=hex"               → use the given algorithm
##                       - bare hex                 → default algorithm (SHA256)
## @note Supports any algorithm accepted by file(<ALGO>).
##       Algorithm names may contain underscores (SHA3_256, etc.).
function(file_checksum_correct _result _file _hash)
	if("${_hash}" STREQUAL "")
		set(${_result} FALSE PARENT_SCOPE)
		return()
	endif()

	if(NOT EXISTS "${_file}")
		set(${_result} FALSE PARENT_SCOPE)
		return()
	endif()

	set(_algo "")
	set(_expected "")

	if(_hash MATCHES "^([A-Za-z0-9_]+)=(.+)$")
		set(_algo "${CMAKE_MATCH_1}")
		set(_expected "${CMAKE_MATCH_2}")
	else()
		set(_algo "SHA256")
		set(_expected "${_hash}")
	endif()

	string(TOUPPER "${_algo}" _algo)

	set(_known_algos
		MD5 SHA1
		SHA224 SHA256 SHA384 SHA512
		SHA3_224 SHA3_256 SHA3_384 SHA3_512
	)
	list(FIND _known_algos "${_algo}" _idx)
	if(_idx EQUAL -1)
		message(WARNING
			"Unknown hash algorithm '${_algo}' for ${_file}. "
			"Known: ${_known_algos}. Treating as mismatch."
		)
		set(${_result} FALSE PARENT_SCOPE)
		return()
	endif()

	file(${_algo} "${_file}" _actual)
	if(_actual STREQUAL _expected)
		set(${_result} TRUE PARENT_SCOPE)
	else()
		set(${_result} FALSE PARENT_SCOPE)
	endif()
endfunction()

## @brief Generate the force-download script and return its path (internal).
## @param[out] out_script Parent-scope path of the generated -P script.
## @param[in]  url        URL to download.
## @param[in]  title      Human-readable title (script filename + messages).
## @param[in]  expected_hash Optional "ALGO=hex" or bare hex.
## @param[in]  max_retries Maximum attempts (default 3).
## @param[in]  current_try Internal try counter (default 1).
## @param[in]  indent_level Status indentation tabs (default 0).
function(_file_generate_download_script out_script url title expected_hash
										max_retries current_try indent_level)
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
	_file_validate_no_traversal("${_basename}")
	set(_full_output "${BUILDMASTER_DOWNLOADSDIR}/${_basename}")
	file(MAKE_DIRECTORY "${BUILDMASTER_DOWNLOADSDIR}")

	sanitize_for_filename(_safe "${title}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/file_download_${_safe}.cmake")

	set(_FILE_URL           "${url}")
	set(_FILE_OUTPUT        "${_full_output}")
	set(_FILE_TITLE         "${title}")
	set(_FILE_EXPECTED_HASH "${expected_hash}")
	set(_FILE_MAX_RETRIES   "${max_retries}")
	set(_FILE_CURRENT_TRY   "${current_try}")
	set(_FILE_INDENT        "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/file_download.cmake.in"
		"${_script}"
		@ONLY
	)

	set(${out_script} "${_script}" PARENT_SCOPE)
endfunction()

## @brief Create (or fatal) a BuildMaster file prerequisite target.
## @param[in] name    Target name.
## @param[in] script  Path to cmake -P script.
## @param[in] comment Progress COMMENT.
## @param[in] depends Optional list of target dependencies.
function(_file_add_prerequisite_target name script comment depends)
	if(TARGET "${name}")
		message(FATAL_ERROR
			"[BuildMaster] file helper: target '${name}' already exists")
	endif()
	if("${comment}" STREQUAL "")
		set(comment "BuildMaster file: ${name}")
	endif()
	add_custom_target(${name}
		COMMAND ${CMAKE_COMMAND} -P "${script}"
		COMMENT "${comment}"
		USES_TERMINAL
		VERBATIM
	)
	if(depends)
		add_dependencies(${name} ${depends})
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_FILE_TARGET_IDS "${name}")
	set_property(GLOBAL PROPERTY BUILDMASTER_FILE_${name}_SCRIPT "${script}")
endfunction()

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

## @brief Always download a file (retries + optional hash); creates a target.
## @param[in] name Target name used with component_dependency / prerequisite.
## @param[in] url  URL to download (basename under BUILDMASTER_DOWNLOADSDIR).
## @param[in] TITLE         Optional human-readable title (default: URL basename).
## @param[in] EXPECTED_HASH Optional "ALGO=hex" or bare hex (SHA256).
## @param[in] MAX_RETRIES   Maximum attempts (default 3).
## @param[in] COMMENT       Optional custom target COMMENT.
## @param[in] DEPENDS       Optional list of CMake targets this waits on.
## @param[in] INDENT        Optional status indent tabs for the generated script.
## @note No out-variable and no include(). The download runs when `name` builds.
function(file_download name url)
	if("${name}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_download: empty name")
	endif()
	if("${url}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_download: empty url")
	endif()

	cmake_parse_arguments(ARG
		""
		"TITLE;EXPECTED_HASH;MAX_RETRIES;COMMENT;INDENT"
		"DEPENDS"
		${ARGN}
	)

	_file_generate_download_script(_script
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

	_file_add_prerequisite_target("${name}" "${_script}" "${ARG_COMMENT}"
		"${ARG_DEPENDS}")
endfunction()

## @brief Cache-aware download; creates a target named `name`.
## @param[in] name Target name used with component_dependency / prerequisite.
## @param[in] url  URL to download (basename under BUILDMASTER_DOWNLOADSDIR).
## @param[in] TITLE         Optional human-readable title (default: URL basename).
## @param[in] EXPECTED_HASH Optional "ALGO=hex" or bare hex (SHA256).
## @param[in] MAX_RETRIES   Maximum attempts (default 3).
## @param[in] COMMENT       Optional custom target COMMENT.
## @param[in] DEPENDS       Optional list of CMake targets this waits on.
## @param[in] INDENT        Optional status indent tabs for the generated script.
## @note Generates force-download + cached wrapper scripts. Builds `name` runs
##       the cached wrapper via cmake -P. No out-variable / include().
function(file_download_cached name url)
	if("${name}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_download_cached: empty name")
	endif()
	if("${url}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_download_cached: empty url")
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

	_file_generate_download_script(_force_script
		"${url}"
		"${ARG_TITLE}"
		"${ARG_EXPECTED_HASH}"
		"${ARG_MAX_RETRIES}"
		"1"
		"${ARG_INDENT}"
	)

	get_filename_component(_basename "${url}" NAME)
	_file_validate_no_traversal("${_basename}")
	set(_full_output "${BUILDMASTER_DOWNLOADSDIR}/${_basename}")

	string(REPEAT "\t" ${ARG_INDENT} _FILE_INDENT)
	sanitize_for_filename(_safe "${ARG_TITLE}")
	set(_script "${BUILDMASTER_SCRIPTS_FILE_DIR}/file_download_cached_${_safe}.cmake")

	set(_FILE_URL           "${url}")
	set(_FILE_OUTPUT        "${_full_output}")
	set(_FILE_TITLE         "${ARG_TITLE}")
	set(_FILE_EXPECTED_HASH "${ARG_EXPECTED_HASH}")
	set(_FILE_MAX_RETRIES   "${ARG_MAX_RETRIES}")
	set(_FILE_FORCE_SCRIPT  "${_force_script}")
	set(_FILE_INDENT        "${_FILE_INDENT}")

	configure_file(
		"${BUILDMASTER_TOOLS_FILE_SRCDIR}/file_download_cached.cmake.in"
		"${_script}"
		@ONLY
	)

	if(NOT ARG_COMMENT)
		set(ARG_COMMENT "Download (cached) ${ARG_TITLE}")
	endif()

	_file_add_prerequisite_target("${name}" "${_script}" "${ARG_COMMENT}"
		"${ARG_DEPENDS}")
endfunction()

## @brief Decompress an archive into a directory; creates a target named `name`.
## @param[in] name    Target name used with component_dependency / prerequisite.
## @param[in] archive Archive path, or basename under BUILDMASTER_DOWNLOADSDIR.
## @param[in] out_dir Destination directory (created if missing).
## @param[in] TITLE   Optional human-readable title.
## @param[in] COMMENT Optional custom target COMMENT.
## @param[in] DEPENDS Optional list of CMake targets this waits on (e.g. the
##            download target for the same archive).
## @param[in] INDENT  Optional status indent tabs for the generated script.
## @note Uses file(ARCHIVE_EXTRACT) inside the generated -P script.
##       No out-variable / include().
function(file_decompress name archive out_dir)
	if("${name}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_decompress: empty name")
	endif()
	if("${archive}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_decompress: empty archive")
	endif()
	if("${out_dir}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] file_decompress: empty out_dir")
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
endfunction()
