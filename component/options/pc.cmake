# =============================================================================
# component/options/pc.cmake — PC={…} parser
# =============================================================================

## @brief Parse `PC={VERSION=…;NAME=…;DESCRIPTION=…;ENABLED=…}` from an options string.
## @param[in]  options_string Same trailing string passed to create_*.
## @param[out] out_present    TRUE if a `PC` key was seen (bare or `PC={…}`).
## @param[out] out_enabled    TRUE if a `.pc` should be written.
## @param[out] out_name       Inner `NAME` or empty (caller defaults to produced).
## @param[out] out_version    Inner `VERSION` or empty.
## @param[out] out_description Inner `DESCRIPTION` or empty (caller defaults to title).
## @note The only valid generative form is `PC={…}`. Bare `PC` / `PC=ON` /
##       `PC=OFF` without braces is FATAL (use `PC={ENABLED=FALSE}` to opt out
##       while keeping the group).
## @note Missing VERSION is FATAL only when enabled. `ENABLED=FALSE` does not
##       require VERSION and does not write a file.
## @note `PC={…}` on a meta is FATAL at create_meta_* (unbounded Requires).
## @note If install already produced a `.pc` at the canonical path, writing
##       one is FATAL (do not clobber an upstream file). That check lives in
##       install_exec, not here.
## @note Unknown inner keys → WARNING and ignored.
function(_bm_opt_parse_pc options_string out_present out_enabled
										out_name out_version out_description)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_pc")
	set(_present FALSE)
	set(_enabled FALSE)
	set(_name "")
	set(_version "")
	set(_description "")

	if(NOT "${options_string}" STREQUAL "")
		_bm_opt_split_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pair("${_pair}" _key _val _ok)
			if(NOT _ok)
				continue()
			endif()
			if(NOT _key STREQUAL "PC")
				continue()
			endif()
			set(_present TRUE)
			_bm_opt_unwrap_brace("${_val}" _inner _brace_ok)
			if(NOT _brace_ok)
				_bm_log_message(COMPONENT FATAL
					"PC must be PC={VERSION=…;NAME=…;ENABLED=…} (got '${_val}')")
			endif()
			set(_enabled TRUE)
			_bm_opt_split_pairs("${_inner}" _inner_pairs)
			foreach(_ip IN LISTS _inner_pairs)
				if(_ip STREQUAL "")
					continue()
				endif()
				_bm_opt_split_pair("${_ip}" _ik _iv _iok)
				if(NOT _iok)
					continue()
				endif()
				if(_ik STREQUAL "VERSION")
					set(_version "${_iv}")
				elseif(_ik STREQUAL "NAME")
					set(_name "${_iv}")
				elseif(_ik STREQUAL "DESCRIPTION")
					set(_description "${_iv}")
				elseif(_ik STREQUAL "ENABLED")
					_bm_opt_flag("${_iv}" _enabled)
				else()
					_bm_log_message(COMPONENT WARNING
						"Unknown PC sub-option '${_ik}' (ignored)")
				endif()
			endforeach()
		endforeach()
	endif()

	if(_present AND _enabled AND "${_version}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"PC={…} with ENABLED=TRUE requires VERSION")
	endif()

	set(${out_present} "${_present}" PARENT_SCOPE)
	set(${out_enabled} "${_enabled}" PARENT_SCOPE)
	set(${out_name} "${_name}" PARENT_SCOPE)
	set(${out_version} "${_version}" PARENT_SCOPE)
	set(${out_description} "${_description}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_pc")
endfunction()
