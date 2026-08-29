# =============================================================================
# component/options/core.cmake — option-string splitters and flag helper
# =============================================================================

## @brief Keys that may appear without '=' (flag form → enabled).
## @note RENAME, BUILDONLY, WHOLE, STRIPRES, PC, GIT and REPACK accept `KEY`,
##       `KEY=` and `KEY=ON|OFF`. Other keys require `KEY=value`. Keep this
##       list in sync with `_bm_opt_parse()`.
## @note `PC` as a bare flag is accepted by the splitter so it is not treated
##       as an unknown token, but a `.pc` is only generated from `PC={…}`.
##       A bare `PC` / `PC=ON` without a brace group is FATAL.
## @note `GIT` as a bare flag / `GIT=` / `GIT={}` is WARNING and ignored.
##       Work lives in `GIT={FETCH;SWITCH=…;RESET;PATCH=…}`.
## @note `REPACK` is a meta-only flag. On `buildmaster_component` it is FATAL.
##       On `buildmaster_meta` it merges every produced static archive of
##       the meta's member leaves into one prefix archive named after the
##       meta id.
## @note `PC={…}` is forbidden on meta components (no sources, no single
##       library contract). Membership can drag an unbounded set of leaves;
##       generating one `.pc` from that would pull Requires the author did
##       not choose and collide with upstream `.pc` files. create_meta_*
##       must FATAL if PC is present.
## @note Non-empty `GIT={…}` is forbidden on meta components (no srcdir).
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME;BUILDONLY;WHOLE;STRIPRES;PC;GIT;REPACK")

# CMake lists use ';' as the element separator. Tokens that contain ';'
# (PC={VERSION=1;NAME=x}) are stored with this stand-in so foreach(IN LISTS)
# does not re-split them. _bm_opt_split_pair restores ';'.
set(_BM_OPT_SEMI "__BM_SEMI__")

## @brief Split an options string on `;` that are not inside `{…}`.
## @param[in]  options_string Raw `"KEY=value;KEY2={A=1;B=2}"` string.
## @param[out] out_pairs      Parent-scope CMake list of tokens. Embedded `;`
##            inside `{…}` are stored as `__BM_SEMI__`.
## @note Brace depth counts nested `{` / `}`. Unbalanced `{` / `}` is FATAL.
##       Empty tokens are dropped. Values still must not contain a raw `;`
##       outside braces.
function(_bm_opt_split_pairs options_string out_pairs)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_split_pairs")
	set(_pairs "")
	set(_cur "")
	set(_depth 0)
	string(LENGTH "${options_string}" _n)
	if(_n GREATER 0)
		math(EXPR _last "${_n} - 1")
		foreach(_i RANGE ${_last})
			string(SUBSTRING "${options_string}" ${_i} 1 _ch)
			if(_ch STREQUAL "{")
				math(EXPR _depth "${_depth} + 1")
				string(APPEND _cur "${_ch}")
			elseif(_ch STREQUAL "}")
				if(_depth EQUAL 0)
					_bm_log_message(COMPONENT FATAL
						"Unmatched '}' in options string")
				endif()
				math(EXPR _depth "${_depth} - 1")
				string(APPEND _cur "${_ch}")
			elseif(_ch STREQUAL ";" AND _depth EQUAL 0)
				string(STRIP "${_cur}" _tok)
				if(NOT _tok STREQUAL "")
					string(REPLACE ";" "${_BM_OPT_SEMI}" _tok "${_tok}")
					list(APPEND _pairs "${_tok}")
				endif()
				set(_cur "")
			else()
				string(APPEND _cur "${_ch}")
			endif()
		endforeach()
	endif()
	if(NOT _depth EQUAL 0)
		_bm_log_message(COMPONENT FATAL
			"Unclosed '{' in options string")
	endif()
	string(STRIP "${_cur}" _tok)
	if(NOT _tok STREQUAL "")
		string(REPLACE ";" "${_BM_OPT_SEMI}" _tok "${_tok}")
		list(APPEND _pairs "${_tok}")
	endif()
	set(${out_pairs} "${_pairs}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_split_pairs")
endfunction()

## @brief Extract the interior of a `{…}` group.
## @param[in]  val        Stripped value that should be `{…}`.
## @param[out] out_inner  Text between the outermost braces (parent scope).
## @param[out] out_ok     TRUE if `val` is a single brace group.
function(_bm_opt_unwrap_brace val out_inner out_ok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_unwrap_brace")
	string(STRIP "${val}" _v)
	set(_ok FALSE)
	set(_inner "")
	string(LENGTH "${_v}" _len)
	if(_len GREATER 1)
		string(SUBSTRING "${_v}" 0 1 _first)
		math(EXPR _last "${_len} - 1")
		string(SUBSTRING "${_v}" ${_last} 1 _lastch)
		if(_first STREQUAL "{" AND _lastch STREQUAL "}")
			math(EXPR _ilen "${_len} - 2")
			string(SUBSTRING "${_v}" 1 ${_ilen} _inner)
			string(STRIP "${_inner}" _inner)
			set(_ok TRUE)
		endif()
	endif()
	set(${out_inner} "${_inner}" PARENT_SCOPE)
	set(${out_ok} "${_ok}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_unwrap_brace")
endfunction()

## @brief Split one options token into key and value.
## @param[in]  pair     Raw token (`KEY=value`, `KEY=`, or `KEY` for flags).
##            May contain `__BM_SEMI__` in place of an embedded `;`.
## @param[out] out_key  Uppercase stripped key (parent scope).
## @param[out] out_val  Value after the first `=` (may be empty; may contain `=`
##            and restored `;`).
## @param[out] out_ok   TRUE if the token is usable; FALSE if ignored.
## @note Tokens without `=` are only accepted when the key is listed in
##       BUILDMASTER_COMPONENT_OPTION_FLAGS (e.g. `RENAME` ≡ `RENAME=ON`).
##       Other bare tokens emit WARNING and set out_ok FALSE.
##       Only the first `=` separates key from value.
function(_bm_opt_split_pair pair out_key out_val out_ok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_split_pair")
	set(_ok TRUE)
	set(_key "")
	set(_val "")

	string(REPLACE "${_BM_OPT_SEMI}" ";" pair "${pair}")

	if("${pair}" STREQUAL "")
		set(_ok FALSE)
	else()
		string(FIND "${pair}" "=" _eq_pos)
		if(_eq_pos EQUAL -1)
			string(STRIP "${pair}" _key)
			string(TOUPPER "${_key}" _key)
			set(_is_flag FALSE)
			foreach(_f IN LISTS BUILDMASTER_COMPONENT_OPTION_FLAGS)
				if(_key STREQUAL "${_f}")
					set(_is_flag TRUE)
					break()
				endif()
			endforeach()
			if(_is_flag)
				set(_val "")
			else()
				_bm_log_message(COMPONENT WARNING
					"Option '${pair}' requires KEY=value form (ignored)")
				set(_ok FALSE)
			endif()
		else()
			string(SUBSTRING "${pair}" 0 ${_eq_pos} _key)
			math(EXPR _val_start "${_eq_pos} + 1")
			string(SUBSTRING "${pair}" ${_val_start} -1 _val)
			string(STRIP "${_key}" _key)
			string(TOUPPER "${_key}" _key)
			string(STRIP "${_val}" _val)
		endif()
	endif()

	set(${out_key} "${_key}" PARENT_SCOPE)
	set(${out_val} "${_val}" PARENT_SCOPE)
	set(${out_ok} "${_ok}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_split_pair")
endfunction()

## @brief Interpret a flag option value as a CMake boolean.
## @param[in]  val      Empty (bare flag form), or an ON/OFF-style string.
## @param[out] out_bool Parent-scope TRUE or FALSE.
## @note Empty value means enabled (`RENAME` ≡ `RENAME=ON` ≡ `RENAME=`).
##       Accepted truthy: `1`, `ON`, `TRUE`, `YES` (case-insensitive).
##       Accepted falsy: `0`, `OFF`, `FALSE`, `NO`.
##       Any other non-empty value → WARNING and FALSE.
function(_bm_opt_flag val out_bool)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_flag")
	if("${val}" STREQUAL "")
		set(${out_bool} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_flag")
		return()
	endif()
	string(TOUPPER "${val}" _v)
	if(_v STREQUAL "1" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE" OR _v STREQUAL "YES")
		set(${out_bool} TRUE PARENT_SCOPE)
	elseif(_v STREQUAL "0" OR _v STREQUAL "OFF" OR _v STREQUAL "FALSE" OR _v STREQUAL "NO")
		set(${out_bool} FALSE PARENT_SCOPE)
	else()
		_bm_log_message(COMPONENT WARNING
			"Unrecognized flag value '${val}' (treated as OFF)")
		set(${out_bool} FALSE PARENT_SCOPE)
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_flag")
endfunction()
