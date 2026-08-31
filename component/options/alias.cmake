# =============================================================================
# component/options/alias.cmake — ALIAS= / ALIAS={…}
# =============================================================================

## @brief Parse `ALIAS=` / `ALIAS={…}` from an optstr.
## @param[in]  options_string Raw trailing optstr (may be empty).
## @param[out] out_aliases    Parent-scope CMake list of alias names.
## @note `ALIAS` / `ALIAS=` / `ALIAS={}` is FATAL (not a flag).
##       An empty token inside `{…}` is FATAL.
##       Duplicate names in the same list: WARNING and dropped.
function(_bm_opt_parse_alias options_string out_aliases)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_alias")
	set(_aliases "")
	if("${options_string}" STREQUAL "")
		set(${out_aliases} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_alias")
		return()
	endif()
	_bm_opt_split_pairs("${options_string}" _pairs)
	foreach(_pair IN LISTS _pairs)
		if(_pair STREQUAL "")
			continue()
		endif()
		_bm_opt_split_pair("${_pair}" _key _val _ok)
		if(NOT _ok OR NOT _key STREQUAL "ALIAS")
			continue()
		endif()
		_bm_opt_unwrap_brace("${_val}" _inner _brace)
		if(_brace)
			set(_body "${_inner}")
		else()
			set(_body "${_val}")
		endif()
		if("${_body}" STREQUAL "")
			_bm_log_message(COMPONENT FATAL
				"ALIAS= requires a target name (ALIAS=Foo::Bar or ALIAS={…})")
		endif()
		if(_brace)
			_bm_opt_split_pairs("${_body}" _names)
		else()
			set(_names "${_body}")
		endif()
		foreach(_n IN LISTS _names)
			string(STRIP "${_n}" _n)
			if("${_n}" STREQUAL "")
				_bm_log_message(COMPONENT FATAL
					"ALIAS= contains an empty name")
			endif()
			list(FIND _aliases "${_n}" _idx)
			if(NOT _idx EQUAL -1)
				_bm_log_message(COMPONENT WARNING
					"ALIAS '${_n}' repeated (ignored)")
				continue()
			endif()
			list(APPEND _aliases "${_n}")
		endforeach()
	endforeach()
	set(${out_aliases} "${_aliases}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_alias")
endfunction()

## @brief Create ALIAS targets for a registered id and fill the lookup table.
## @param[in] _id      Component or meta id (INTERFACE stub already exists).
## @param[in] _aliases CMake list of alias names (may be empty).
## @note Alias equal to `_id` is FATAL. Existing TARGET that is not already
##       an ALIAS of `_id` is FATAL. Same alias → same id is a no-op.
function(_bm_alias_apply _id _aliases)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_alias_apply")
	if("${_id}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "_bm_alias_apply: empty id")
	endif()
	foreach(_a IN LISTS _aliases)
		if("${_a}" STREQUAL "")
			continue()
		endif()
		if(_a STREQUAL "${_id}")
			_bm_log_message(COMPONENT FATAL
				"ALIAS '${_a}' cannot be the component id itself")
		endif()
		get_property(_owner GLOBAL PROPERTY BUILDMASTER_ALIAS_${_a})
		if(NOT "${_owner}" STREQUAL "" AND NOT _owner STREQUAL "${_id}")
			_bm_log_message(COMPONENT FATAL
				"ALIAS '${_a}' already maps to '${_owner}'")
		endif()
		if(TARGET "${_a}")
			if(NOT TARGET "${_id}")
				_bm_log_message(COMPONENT FATAL
					"ALIAS '${_a}' already exists as a target")
			endif()
			get_property(_aliased TARGET "${_a}" PROPERTY ALIASED_TARGET)
			if(NOT _aliased STREQUAL "${_id}")
				_bm_log_message(COMPONENT FATAL
					"ALIAS '${_a}' already exists as a target")
			endif()
		else()
			add_library("${_a}" ALIAS "${_id}")
		endif()
		set_property(GLOBAL PROPERTY BUILDMASTER_ALIAS_${_a} "${_id}")
		set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_${_id}_ALIASES
			"${_a}")
		_bm_log_message(COMPONENT DEBUG "ALIAS ${_a} → ${_id}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_alias_apply")
endfunction()

## @brief Resolve an alias token to its component/meta id.
## @param[in]  _token   Id or alias (or raw dest).
## @param[out] out_id   Parent-scope id if `_token` is an alias; else `_token`.
function(_bm_alias_resolve _token out_id)
	if("${_token}" STREQUAL "")
		set(${out_id} "" PARENT_SCOPE)
		return()
	endif()
	get_property(_owner GLOBAL PROPERTY BUILDMASTER_ALIAS_${_token})
	if(NOT "${_owner}" STREQUAL "")
		set(${out_id} "${_owner}" PARENT_SCOPE)
	else()
		set(${out_id} "${_token}" PARENT_SCOPE)
	endif()
endfunction()
