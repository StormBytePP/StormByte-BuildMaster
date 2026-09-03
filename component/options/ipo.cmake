# =============================================================================
# component/options/ipo.cmake — IPO= optstr
# =============================================================================

## @brief Parse `IPO` / `IPO=` / `IPO=on|off|fat` from an options string.
## @param[in]  options_string Raw optstr (may be empty).
## @param[out] out_mode       Parent-scope mode:
##            `inherit` — key absent (translator uses the parent IPO state);
##            `on`      — thin LTO (`IPO`, `IPO=`, `IPO=on`);
##            `off`     — strip flto/GL/LTCG and do not put them back;
##            `fat`     — `on` plus `-ffat-lto-objects` on gcc/clang.
## @note Bare `IPO` and `IPO=` are thin `on`, same idea as `WHOLE`.
##       `ON`/`TRUE`/`YES`/`1` → `on`. `OFF`/`FALSE`/`NO`/`0` → `off`.
##       Anything else → FATAL.
## @note Several `IPO=` keys: last one wins.
function(_bm_opt_parse_ipo options_string out_mode)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_ipo")
	set(_mode "inherit")
	if(NOT "${options_string}" STREQUAL "")
		_bm_opt_split_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pair("${_pair}" _key _val _ok)
			if(NOT _ok OR NOT _key STREQUAL "IPO")
				continue()
			endif()
			string(TOUPPER "${_val}" _v)
			if(_v STREQUAL "" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE"
					OR _v STREQUAL "YES" OR _v STREQUAL "1")
				set(_mode "on")
			elseif(_v STREQUAL "OFF" OR _v STREQUAL "FALSE"
					OR _v STREQUAL "NO" OR _v STREQUAL "0")
				set(_mode "off")
			elseif(_v STREQUAL "FAT")
				set(_mode "fat")
			else()
				_bm_log_message(COMPONENT FATAL
					"IPO: invalid value '${_val}' (on|off|fat, or bare IPO)")
			endif()
		endforeach()
	endif()
	set(${out_mode} "${_mode}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_ipo")
endfunction()
