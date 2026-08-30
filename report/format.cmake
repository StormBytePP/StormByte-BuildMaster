# =============================================================================
# report/format.cmake — column pad, wrap, TYPE labels
# =============================================================================

## @brief Right-pad `_text` with spaces to `_width`.
## @param[in]  _text   Cell contents (no newlines).
## @param[in]  _width  Minimum width in characters.
## @param[out] _out    Parent-scope padded string.
## @note If `_text` is already longer than `_width`, it is returned as-is
##       (the table column grows; ids are never wrapped).
function(_bm_report_pad _text _width _out)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_pad")
	string(LENGTH "${_text}" _len)
	if(_len LESS _width)
		math(EXPR _need "${_width} - ${_len}")
		string(REPEAT " " ${_need} _sp)
		set(${_out} "${_text}${_sp}" PARENT_SCOPE)
	else()
		set(${_out} "${_text}" PARENT_SCOPE)
	endif()
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_pad")
endfunction()

## @brief Max string length of a CMake list.
## @param[in]  _items CMake list.
## @param[out] _out   Parent-scope integer (0 if empty).
function(_bm_report_max_len _items _out)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_max_len")
	set(_m 0)
	foreach(_it IN LISTS _items)
		string(LENGTH "${_it}" _l)
		if(_l GREATER _m)
			set(_m "${_l}")
		endif()
	endforeach()
	set(${_out} "${_m}" PARENT_SCOPE)
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_max_len")
endfunction()

## @brief Wrap `_text` to `_width` on spaces; long tokens stay intact.
## @param[in]  _text  Value to wrap (no newlines required).
## @param[in]  _width Soft maximum per line (default 88).
## @param[out] _out   Parent-scope CMake list of lines.
## @note Used only for child values (CFLAGS, paths). Table rows are never
##       wrapped here.
function(_bm_report_wrap _text _width _out)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_wrap")
	if(_width LESS 16)
		set(_width 88)
	endif()
	string(STRIP "${_text}" _text)
	if(_text STREQUAL "")
		set(${_out} "" PARENT_SCOPE)
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_wrap")
		return()
	endif()
	set(_lines "")
	set(_cur "")
	string(REPLACE "\n" " " _text "${_text}")
	separate_arguments(_toks UNIX_COMMAND "${_text}")
	foreach(_t IN LISTS _toks)
		if(_cur STREQUAL "")
			set(_cur "${_t}")
		else()
			string(LENGTH "${_cur} ${_t}" _nl)
			if(_nl GREATER _width)
				list(APPEND _lines "${_cur}")
				set(_cur "${_t}")
			else()
				set(_cur "${_cur} ${_t}")
			endif()
		endif()
	endforeach()
	if(NOT _cur STREQUAL "")
		list(APPEND _lines "${_cur}")
	endif()
	set(${_out} "${_lines}" PARENT_SCOPE)
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_wrap")
endfunction()

## @brief Log one child key/value under a component row.
## @param[in] _key    Label (`CFLAGS`, `NEEDED BY`, `LINKFLAGS`, …).
## @param[in] _value  Raw value (may be long).
## @param[in] _key_w  Padded key width.
## @param[in] _indent Logger indent for the first line.
## @note Continuation lines use the same indent and a blank key so the
##       value column stays aligned. Empty `_value` is a no-op.
function(_bm_report_child _key _value _key_w _indent)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_child")
	if(_value STREQUAL "")
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_child")
		return()
	endif()
	_bm_report_pad("${_key}" "${_key_w}" _kpad)
	_bm_report_wrap("${_value}" 88 _lines)
	set(_first TRUE)
	foreach(_ln IN LISTS _lines)
		if(_first)
			_bm_log_message(REPORT STATUS "${_kpad}${_ln}" "${_indent}")
			set(_first FALSE)
		else()
			_bm_report_pad("" "${_key_w}" _blank)
			_bm_log_message(REPORT STATUS "${_blank}${_ln}" "${_indent}")
		endif()
	endforeach()
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_child")
endfunction()

## @brief TYPE cell for the components table.
## @param[in]  _id  Component or meta id.
## @param[out] _out Parent-scope label.
## @note Groups are not labelled here; the dump skips them.
##       Headers-only is `Component (headers only)`.
##       Meta is `Meta`. Otherwise `Component (cmake)` / `Component (meson)`.
function(_bm_report_type_label _id _out)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_type_label")
	_bm_meta_is("${_id}" _is_meta)
	if(_is_meta)
		set(${_out} "Meta" PARENT_SCOPE)
		_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_type_label")
		return()
	endif()
	get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
	get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_MODE)
	if(_mode STREQUAL "headers" OR _sys STREQUAL "none")
		set(${_out} "Component (headers only)" PARENT_SCOPE)
	elseif(_sys STREQUAL "meson")
		set(${_out} "Component (meson)" PARENT_SCOPE)
	else()
		set(${_out} "Component (cmake)" PARENT_SCOPE)
	endif()
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_type_label")
endfunction()

## @brief Join a CMake list with `, `.
## @param[in]  _items List (may be empty).
## @param[out] _out   Parent-scope string; empty if `_items` is empty.
function(_bm_report_join_comma _items _out)
	_bm_log_message(REPORT LOWLEVEL "Entering _bm_report_join_comma")
	if(_items STREQUAL "")
		set(${_out} "" PARENT_SCOPE)
	else()
		_bm_list_join(_j "${_items}" ", ")
		set(${_out} "${_j}" PARENT_SCOPE)
	endif()
	_bm_log_message(REPORT LOWLEVEL "Exiting _bm_report_join_comma")
endfunction()
