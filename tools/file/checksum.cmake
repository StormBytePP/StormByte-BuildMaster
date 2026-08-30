# =============================================================================
# tools/file/checksum.cmake — path safety + hash check
# =============================================================================

## @brief Validate that a path does not contain path-traversal sequences.
## @param[in] _path Path to validate (URL basename, archive path, or extract dir).
## @note FATAL if the path contains ".." anywhere. Used before writing under
##       BUILDMASTER_DOWNLOADSDIR or extracting an archive.
function(_bm_file_validate_no_traversal _path)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_file_validate_no_traversal")
	if("${_path}" MATCHES "\\.\\.")
		_bm_log_message(FILE FATAL
			"Path traversal detected (contains '..'):\n  ${_path}\nRefusing to continue for security reasons."
		)
	endif()
	_bm_log_message(FILE LOWLEVEL "Exiting _bm_file_validate_no_traversal")
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
##       Unknown algorithms → WARNING and FALSE (treated as mismatch).
## @note Last check is stored in CACHE INTERNAL:
##       BUILDMASTER_FILE_LAST_HASH_{ALGO,EXPECTED,ACTUAL,FILE} so the
##       download script can print a friendly FATAL.
function(_bm_tools_file_checksum _result _file _hash)
	_bm_log_message(FILE LOWLEVEL "Entering _bm_tools_file_checksum")
	set(BUILDMASTER_FILE_LAST_HASH_FILE "${_file}" CACHE INTERNAL "")
	set(BUILDMASTER_FILE_LAST_HASH_ALGO "" CACHE INTERNAL "")
	set(BUILDMASTER_FILE_LAST_HASH_EXPECTED "" CACHE INTERNAL "")
	set(BUILDMASTER_FILE_LAST_HASH_ACTUAL "" CACHE INTERNAL "")

	if("${_hash}" STREQUAL "")
		set(${_result} FALSE PARENT_SCOPE)
		_bm_log_message(FILE LOWLEVEL "Exiting _bm_tools_file_checksum")
		return()
	endif()

	if(NOT EXISTS "${_file}")
		set(${_result} FALSE PARENT_SCOPE)
		_bm_log_message(FILE LOWLEVEL "Exiting _bm_tools_file_checksum")
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
	string(TOLOWER "${_expected}" _expected)

	set(_known_algos
		MD5 SHA1
		SHA224 SHA256 SHA384 SHA512
		SHA3_224 SHA3_256 SHA3_384 SHA3_512
	)
	list(FIND _known_algos "${_algo}" _idx)
	if(_idx EQUAL -1)
		_bm_log_message(FILE WARNING
			"Unknown hash algorithm '${_algo}' for ${_file}. Known: ${_known_algos}. Treating as mismatch."
		)
		set(BUILDMASTER_FILE_LAST_HASH_ALGO "${_algo}" CACHE INTERNAL "")
		set(BUILDMASTER_FILE_LAST_HASH_EXPECTED "${_expected}" CACHE INTERNAL "")
		set(${_result} FALSE PARENT_SCOPE)
		_bm_log_message(FILE LOWLEVEL "Exiting _bm_tools_file_checksum")
		return()
	endif()

	file(${_algo} "${_file}" _actual)
	string(TOLOWER "${_actual}" _actual)

	set(BUILDMASTER_FILE_LAST_HASH_ALGO "${_algo}" CACHE INTERNAL "")
	set(BUILDMASTER_FILE_LAST_HASH_EXPECTED "${_expected}" CACHE INTERNAL "")
	set(BUILDMASTER_FILE_LAST_HASH_ACTUAL "${_actual}" CACHE INTERNAL "")

	if(_actual STREQUAL _expected)
		_bm_log_message(FILE DEBUG "Hash OK ${_algo} ${_file}")
		set(${_result} TRUE PARENT_SCOPE)
	else()
		_bm_log_message(FILE DEBUG
			"Hash mismatch ${_algo} ${_file} expected=${_expected} actual=${_actual}")
		set(${_result} FALSE PARENT_SCOPE)
	endif()
	_bm_log_message(FILE LOWLEVEL "Exiting _bm_tools_file_checksum")
endfunction()
