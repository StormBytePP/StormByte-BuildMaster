# =============================================================================
# component/options/files.cmake — FILES={URL=…;NAME=…;UNPACK;SOURCE;…}
# =============================================================================

## @brief Parse one FILES group into parallel slot variables (append).
## @param[in] _group Inner text: URL=…;NAME=…;UNPACK;SOURCE[=rel];…
## @param[in,out] _urls_var _names_var _hashes_var _algos_var
## @param[in,out] _unpacks_var _forces_var _sources_var _titles_var
## @note SOURCE without UNPACK is FATAL. SOURCE with empty value means `.`.
## @note Hash: MD5=, SHA256=, or EXPECTED_HASH=ALGO=hex.
## @note UNPACK / FORCE / SOURCE as bare tokens are group-local flags.
##       They are not in BUILDMASTER_COMPONENT_OPTION_FLAGS (that list is
##       the outer optstr). Parsed here before `_bm_opt_split_pair`.
function(_bm_opt_parse_files_group _group
		_urls_var _names_var _hashes_var _algos_var
		_unpacks_var _forces_var _sources_var _titles_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_files_group")
	set(_url "")
	set(_name "")
	set(_hash "")
	set(_algo "")
	set(_unpack FALSE)
	set(_force FALSE)
	set(_source "")
	set(_title "")
	_bm_opt_split_pairs("${_group}" _gpairs)
	foreach(_pair IN LISTS _gpairs)
		string(REPLACE "${_BM_OPT_SEMI}" ";" _pair "${_pair}")
		string(STRIP "${_pair}" _pair)
		string(TOUPPER "${_pair}" _up)
		if(_up STREQUAL "UNPACK")
			set(_unpack TRUE)
			continue()
		endif()
		if(_up STREQUAL "FORCE")
			set(_force TRUE)
			continue()
		endif()
		if(_up STREQUAL "SOURCE")
			set(_source ".")
			continue()
		endif()
		_bm_opt_split_pair("${_pair}" _k _v _ok)
		if(NOT _ok)
			continue()
		endif()
		if(_k STREQUAL "URL")
			set(_url "${_v}")
		elseif(_k STREQUAL "NAME")
			set(_name "${_v}")
		elseif(_k STREQUAL "MD5")
			set(_algo "MD5")
			set(_hash "${_v}")
		elseif(_k STREQUAL "SHA256")
			set(_algo "SHA256")
			set(_hash "${_v}")
		elseif(_k STREQUAL "EXPECTED_HASH")
			string(FIND "${_v}" "=" _eq)
			if(_eq LESS 1)
				_bm_log_message(COMPONENT FATAL
					"FILES EXPECTED_HASH= needs ALGO=hex")
			endif()
			string(SUBSTRING "${_v}" 0 ${_eq} _algo)
			math(EXPR _rest "${_eq} + 1")
			string(SUBSTRING "${_v}" ${_rest} -1 _hash)
			string(TOUPPER "${_algo}" _algo)
		elseif(_k STREQUAL "UNPACK")
			_bm_opt_flag("${_v}" _unpack)
		elseif(_k STREQUAL "FORCE")
			_bm_opt_flag("${_v}" _force)
		elseif(_k STREQUAL "SOURCE")
			if("${_v}" STREQUAL "")
				set(_source ".")
			else()
				set(_source "${_v}")
			endif()
		elseif(_k STREQUAL "TITLE")
			set(_title "${_v}")
		else()
			_bm_log_message(COMPONENT WARNING
				"FILES: unknown key '${_k}' ignored")
		endif()
	endforeach()
	if("${_url}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "FILES group requires URL=")
	endif()
	if("${_name}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "FILES group requires NAME=")
	endif()
	if(NOT "${_source}" STREQUAL "" AND NOT _unpack)
		_bm_log_message(COMPONENT FATAL
			"FILES SOURCE requires UNPACK")
	endif()
	list(APPEND ${_urls_var} "${_url}")
	list(APPEND ${_names_var} "${_name}")
	list(APPEND ${_hashes_var} "${_hash}")
	list(APPEND ${_algos_var} "${_algo}")
	if(_unpack)
		list(APPEND ${_unpacks_var} TRUE)
	else()
		list(APPEND ${_unpacks_var} FALSE)
	endif()
	if(_force)
		list(APPEND ${_forces_var} TRUE)
	else()
		list(APPEND ${_forces_var} FALSE)
	endif()
	list(APPEND ${_sources_var} "${_source}")
	list(APPEND ${_titles_var} "${_title}")
	set(${_urls_var} "${${_urls_var}}" PARENT_SCOPE)
	set(${_names_var} "${${_names_var}}" PARENT_SCOPE)
	set(${_hashes_var} "${${_hashes_var}}" PARENT_SCOPE)
	set(${_algos_var} "${${_algos_var}}" PARENT_SCOPE)
	set(${_unpacks_var} "${${_unpacks_var}}" PARENT_SCOPE)
	set(${_forces_var} "${${_forces_var}}" PARENT_SCOPE)
	set(${_sources_var} "${${_sources_var}}" PARENT_SCOPE)
	set(${_titles_var} "${${_titles_var}}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_files_group")
endfunction()

## @brief Parse FILES= from an optstr.
## @param[in]  options_string Raw trailing optstr.
## @param[out] out_present TRUE if the FILES key appears (even empty).
## @param[out] out_urls out_names out_hashes out_algos
## @param[out] out_unpacks out_forces out_sources out_titles Parallel lists.
## @note Empty FILES / FILES= / FILES={} → WARNING, present TRUE, lists empty.
## @note Nested `{{…};{…}}` = several groups. At most one SOURCE across groups.
function(_bm_opt_parse_files options_string
		out_present out_urls out_names out_hashes out_algos
		out_unpacks out_forces out_sources out_titles)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_files")
	set(_present FALSE)
	set(_urls "")
	set(_names "")
	set(_hashes "")
	set(_algos "")
	set(_unpacks "")
	set(_forces "")
	set(_sources "")
	set(_titles "")
	_bm_opt_split_pairs("${options_string}" _pairs)
	foreach(_pair IN LISTS _pairs)
		_bm_opt_split_pair("${_pair}" _key _val _ok)
		if(NOT _ok)
			continue()
		endif()
		if(NOT _key STREQUAL "FILES")
			continue()
		endif()
		set(_present TRUE)
		_bm_opt_unwrap_brace("${_val}" _inner _brace)
		if(_brace)
			set(_body "${_inner}")
		else()
			set(_body "${_val}")
		endif()
		if("${_body}" STREQUAL "")
			_bm_log_message(COMPONENT WARNING "FILES={} is empty (ignored)")
			continue()
		endif()
		string(STRIP "${_body}" _body)
		string(SUBSTRING "${_body}" 0 1 _ch0)
		if(_ch0 STREQUAL "{")
			_bm_opt_split_pairs("${_body}" _groups)
			foreach(_g IN LISTS _groups)
				_bm_opt_unwrap_brace("${_g}" _ginner _gok)
				if(_gok)
					set(_g "${_ginner}")
				endif()
				_bm_opt_parse_files_group("${_g}"
					_urls _names _hashes _algos
					_unpacks _forces _sources _titles)
			endforeach()
		else()
			_bm_opt_parse_files_group("${_body}"
				_urls _names _hashes _algos
				_unpacks _forces _sources _titles)
		endif()
	endforeach()
	set(_nsrc 0)
	foreach(_s IN LISTS _sources)
		if(NOT "${_s}" STREQUAL "")
			math(EXPR _nsrc "${_nsrc} + 1")
		endif()
	endforeach()
	if(_nsrc GREATER 1)
		_bm_log_message(COMPONENT FATAL
			"FILES: at most one SOURCE group per component")
	endif()
	set(${out_present} "${_present}" PARENT_SCOPE)
	set(${out_urls} "${_urls}" PARENT_SCOPE)
	set(${out_names} "${_names}" PARENT_SCOPE)
	set(${out_hashes} "${_hashes}" PARENT_SCOPE)
	set(${out_algos} "${_algos}" PARENT_SCOPE)
	set(${out_unpacks} "${_unpacks}" PARENT_SCOPE)
	set(${out_forces} "${_forces}" PARENT_SCOPE)
	set(${out_sources} "${_sources}" PARENT_SCOPE)
	set(${out_titles} "${_titles}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_files")
endfunction()

## @brief `list(GET)` that yields "" when the slot was dropped as empty.
function(_bm_files_slot_get _lst _i out_var)
	list(LENGTH _lst _n)
	if(_i LESS _n)
		list(GET _lst ${_i} _v)
	else()
		set(_v "")
	endif()
	set(${out_var} "${_v}" PARENT_SCOPE)
endfunction()

## @brief Download / unpack every FILES group stored on `_id`.
## @param[in] _id Registered component.
## @note Runs at finalize, before pending detect and nested configure.
## @note Cache file is `${BUILDMASTER_DOWNLOADSDIR}/<url-basename>` — the
##       file helpers have no DESTINATION= (ignored if passed).
##       Unpack: `${BUILDMASTER_BINDIR}/files/<sanitized NAME>/`.
## @note SOURCE group rewrites `BUILDMASTER_COMPONENT_<id>_SRCDIR`.
##       Other UNPACK groups append to `FILES_INCLUDES` (private `-I`).
## @note FORCE uses `buildmaster_download` (always fetch). Else cached.
function(_bm_comp_apply_files _id)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_apply_files")
	get_property(_urls GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_URLS)
	if(NOT _urls)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_apply_files")
		return()
	endif()
	get_property(_names GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_NAMES)
	get_property(_hashes GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_HASHES)
	get_property(_algos GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_ALGOS)
	get_property(_unpacks GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_UNPACKS)
	get_property(_forces GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_FORCES)
	get_property(_sources GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_SOURCES)
	get_property(_titles GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_TITLES)
	get_property(_ctitle GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_TITLE)

	if(NOT BUILDMASTER_DOWNLOADSDIR)
		_bm_log_message(COMPONENT FATAL
			"FILES '${_id}': BUILDMASTER_DOWNLOADSDIR is empty")
	endif()
	if(NOT BUILDMASTER_BINDIR)
		_bm_log_message(COMPONENT FATAL
			"FILES '${_id}': BUILDMASTER_BINDIR is empty")
	endif()
	file(MAKE_DIRECTORY "${BUILDMASTER_DOWNLOADSDIR}")
	file(MAKE_DIRECTORY "${BUILDMASTER_BINDIR}/files")

	set(_includes "")
	set(_i 0)
	foreach(_url IN LISTS _urls)
		_bm_files_slot_get("${_names}" ${_i} _name)
		_bm_files_slot_get("${_hashes}" ${_i} _hash)
		_bm_files_slot_get("${_algos}" ${_i} _algo)
		_bm_files_slot_get("${_unpacks}" ${_i} _unp)
		_bm_files_slot_get("${_forces}" ${_i} _frc)
		_bm_files_slot_get("${_sources}" ${_i} _src)
		_bm_files_slot_get("${_titles}" ${_i} _title)
		math(EXPR _i "${_i} + 1")

		if("${_name}" STREQUAL "")
			_bm_log_message(COMPONENT FATAL
				"FILES '${_id}': NAME slot ${_i} missing")
		endif()
		if("${_title}" STREQUAL "")
			set(_title "${_ctitle} / ${_name}")
		endif()
		_bm_path_sanitize(_safe "${_name}")
		get_filename_component(_base "${_url}" NAME)
		set(_archive "${BUILDMASTER_DOWNLOADSDIR}/${_base}")
		set(_tgt "_bm_files_${_id}_${_safe}")

		set(_hash_args "")
		if(NOT "${_hash}" STREQUAL "" AND NOT "${_algo}" STREQUAL "")
			set(_hash_args EXPECTED_HASH "${_algo}=${_hash}")
		endif()

		if(_frc)
			_bm_log_message(COMPONENT DEBUG
				"${_id}: FILES FORCE download ${_url} → ${_archive}")
			buildmaster_download("${_tgt}" "${_url}"
				${_hash_args}
				TITLE "${_title}")
		else()
			_bm_log_message(COMPONENT DEBUG
				"${_id}: FILES cached download ${_url} → ${_archive}")
			buildmaster_download_cached("${_tgt}" "${_url}"
				${_hash_args}
				TITLE "${_title}")
		endif()

		if(NOT _unp)
			continue()
		endif()
		if(NOT EXISTS "${_archive}")
			_bm_log_message(COMPONENT FATAL
				"FILES '${_id}': archive missing after download (${_archive})")
		endif()
		set(_udir "${BUILDMASTER_BINDIR}/files/${_safe}")
		if(EXISTS "${_udir}")
			file(REMOVE_RECURSE "${_udir}")
		endif()
		file(MAKE_DIRECTORY "${_udir}")
		buildmaster_decompress("${_tgt}_unpack" "${_archive}" "${_udir}"
			TITLE "${_title} unpack")
		if(NOT "${_src}" STREQUAL "")
			if(_src STREQUAL ".")
				set(_tree "${_udir}")
			else()
				set(_tree "${_udir}/${_src}")
			endif()
			if(NOT IS_DIRECTORY "${_tree}")
				_bm_log_message(COMPONENT FATAL
					"FILES '${_id}': SOURCE '${_src}' is not a directory under ${_udir}")
			endif()
			set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SRCDIR "${_tree}")
			_bm_log_message(COMPONENT DEBUG
				"${_id}: FILES SOURCE → ${_tree}")
		else()
			list(APPEND _includes "${_udir}")
		endif()
	endforeach()

	if(_includes)
		set_property(GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${_id}_FILES_INCLUDES "${_includes}")
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_apply_files")
endfunction()

## @brief After SOURCE unpack, detect backend and translate factory options.
## @param[in] _id Component whose SYSTEM is `pending`.
function(_bm_comp_resolve_pending_files _id)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_resolve_pending_files")
	get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
	if(NOT _sys STREQUAL "pending")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_resolve_pending_files")
		return()
	endif()
	get_property(_srcdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SRCDIR)
	get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_MODE)
	get_property(_raw GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FACTORY_OPTIONS)
	_bm_factory_detect("${_srcdir}" "${_mode}" _nsys)
	_bm_factory_translate_options("${_nsys}" "${_srcdir}" "${_raw}" _xopts)
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM "${_nsys}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTIONS "${_xopts}")
	_bm_log_message(COMPONENT DEBUG
		"${_id}: pending FILES SOURCE resolved as ${_nsys} (${_srcdir})")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_resolve_pending_files")
endfunction()
