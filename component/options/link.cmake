# =============================================================================
# component/options/link.cmake — LINK= / LINK={…} parser
# =============================================================================

## @brief Parse `LINK=<name>` / `LINK={name;name2}` from a component options string.
## @param[in]  options_string Trailing `"KEY=value;…"` passed to create_*.
## @param[out] out_items      Parent-scope CMake list of raw linker names
##            (empty if `LINK` was omitted or `LINK={}`).
## @note Items are **external to BuildMaster**. They are forwarded verbatim
##       onto the component INTERFACE
##       (`target_link_libraries(<id> INTERFACE …)`) and therefore propagate
##       along the CMake link chain to the final artefact (`.dll` / `.so` /
##       executable) that consumes that id. They do not rewrite the nested
##       third-party build and they do not fix a link line that never goes
##       through the BM INTERFACE.
## @note Items are raw linker names (`shlwapi`, `ws2_32`), not component ids,
##       not metas, not CMake targets, and not library specs under the install
##       prefix. Use `buildmaster_link()` for BM graph nodes. A name that
##       collides with an existing TARGET may be resolved by CMake as that
##       target — do not use colliding names.
## @note One item: `LINK=shlwapi`. Several: `LINK={shlwapi;ws2_32}` — `;`
##       inside `{…}` is not a pair break. Bare `LINK` / `LINK=` is FATAL.
##       Several items without braces is FATAL. Empty tokens inside `{…}`
##       are dropped. This function does not interpret sibling keys.
function(_bm_opt_parse_link options_string out_items)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_link")
	set(_items "")

	if(NOT "${options_string}" STREQUAL "")
		_bm_opt_split_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pair("${_pair}" _key _val _ok)
			if(NOT _ok OR NOT _key STREQUAL "LINK")
				continue()
			endif()
			if(_val STREQUAL "")
				_bm_log_message(COMPONENT FATAL
					"LINK requires LINK=<name> or LINK={name;name2} (bare LINK is invalid)")
			endif()
			_bm_opt_unwrap_brace("${_val}" _inner _brace)
			if(_brace)
				if(NOT _inner STREQUAL "")
					_bm_opt_split_pairs("${_inner}" _inner_pairs)
					foreach(_it IN LISTS _inner_pairs)
						string(STRIP "${_it}" _it)
						if(_it STREQUAL "")
							continue()
						endif()
						list(APPEND _items "${_it}")
					endforeach()
				endif()
			else()
				if(_val MATCHES ";")
					_bm_log_message(COMPONENT FATAL
						"LINK with several items must be LINK={a;b} (got '${_val}')")
				endif()
				list(APPEND _items "${_val}")
			endif()
		endforeach()
	endif()

	if(_items)
		_bm_log_message(COMPONENT DEBUG "LINK items: ${_items}")
	endif()
	set(${out_items} "${_items}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_link")
endfunction()
