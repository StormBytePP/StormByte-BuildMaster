# =============================================================================
# component/options/require_tool.cmake — REQUIRE_TOOL= / REQUIRE_TOOL={…}
# =============================================================================

## @brief Parse `REQUIRE_TOOL` from an optstr and demand each extra.
## @param[in] options_string Raw trailing optstr (may be empty).
## @note `REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}` → WARNING,
##       no demand. Unknown extra id → FATAL inside `_bm_tools_demand_extra`.
function(_bm_opt_parse_require_tool options_string)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_require_tool")
	if("${options_string}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_require_tool")
		return()
	endif()

	set(_seen FALSE)
	set(_ids "")
	_bm_opt_split_pairs("${options_string}" _pairs)
	foreach(_pair IN LISTS _pairs)
		if(_pair STREQUAL "")
			continue()
		endif()
		_bm_opt_split_pair("${_pair}" _key _val _ok)
		if(NOT _ok OR NOT _key STREQUAL "REQUIRE_TOOL")
			continue()
		endif()
		set(_seen TRUE)
		_bm_opt_unwrap_brace("${_val}" _inner _brace)
		if(_brace)
			set(_body "${_inner}")
		else()
			set(_body "${_val}")
		endif()
		if("${_body}" STREQUAL "")
			_bm_log_message(COMPONENT WARNING
				"REQUIRE_TOOL= is empty (ignored). Use REQUIRE_TOOL=pkgconfig or REQUIRE_TOOL={pkgconfig;…}.")
			continue()
		endif()
		_bm_opt_split_pairs("${_body}" _items)
		foreach(_id IN LISTS _items)
			string(STRIP "${_id}" _id)
			if(_id STREQUAL "")
				continue()
			endif()
			list(APPEND _ids "${_id}")
		endforeach()
	endforeach()

	if(_seen AND _ids STREQUAL "")
		_bm_log_message(COMPONENT WARNING
			"REQUIRE_TOOL= is empty (ignored). Use REQUIRE_TOOL=pkgconfig or REQUIRE_TOOL={pkgconfig;…}.")
	endif()

	foreach(_id IN LISTS _ids)
		_bm_tools_demand_extra("${_id}")
	endforeach()

	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_require_tool")
endfunction()
