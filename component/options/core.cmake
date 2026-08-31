# =============================================================================
# component/options/core.cmake — option-string splitters and flag helper
# =============================================================================

## @brief Keys that may appear without '=' (flag form → enabled).
## @note RENAME, NOINSTALL, WHOLE, STRIPRES, PC, GIT, REPACK, FILES and
##       REQUIRE_TOOL accept `KEY`, `KEY=` and `KEY=ON|OFF`. Other keys
##       require `KEY=value`. Keep this list in sync with `_bm_opt_parse()`.
## @note `NOINSTALL` is a bare flag. `NOINSTALL=` / truthy values warn and
##       enable. Falsy values are FATAL. Parsed in `_bm_opt_parse_noinstall`.
## @note `BUILDONLY` is not a flag. The key is FATAL (`use NOINSTALL`).
## @note `PC` as a bare flag is accepted by the splitter so it is not treated
##       as an unknown token, but a `.pc` is only generated from `PC={…}`.
##       A bare `PC` / `PC=ON` without a brace group is FATAL.
## @note `GIT` as a bare flag / `GIT=` / `GIT={}` is WARNING and ignored.
##       Work lives in `GIT={FETCH;SWITCH=…;RESET;PATCH=…}`.
## @note `FILES` as a bare flag / `FILES=` / `FILES={}` is WARNING and ignored.
##       Work lives in `FILES={URL=…;NAME=…;…}` or `FILES={{…};{…}}`.
## @note `REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}` is WARNING
##       and ignored (`Use REQUIRE_TOOL=pkgconfig or REQUIRE_TOOL={…}`).
##       Unknown extra ids are FATAL in `_bm_tools_demand_extra`.
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
## @note Any `FILES` key is forbidden on meta components (no srcdir, no
##       nested configure).
## @note `REQUIRE_TOOL` is allowed on meta and component.
## @note `NOINSTALL` is allowed on meta and component. On a meta it is
##       stamped onto every member at finalize (prevalent).
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME;NOINSTALL;BUILDONLY;WHOLE;STRIPRES;PC;GIT;REPACK;FILES;REQUIRE_TOOL")

# CMake lists use ';' as the element separator. Tokens that contain ';'
# inside `{…}` are stored with this stand-in so foreach(IN LISTS) does
# not re-split them. _bm_opt_split_pair restores ';'.
# CACHE INTERNAL: add_subdirectory(buildmaster) must not hide this from
# sibling CMakeLists (a host project never re-includes helpers.cmake).
set(_BM_OPT_SEMI "__BM_SEMI__" CACHE INTERNAL "BuildMaster optstr stand-in for ';' inside {…}")

## @brief Re-join a value that `function()` split on `;`.
## @param[out] out_var Parent-scope flat string.
## @param[in]  ARGN    Pieces of the original string (quoted or not).
## @note Out-first. Glue is a variable so `string(JOIN ; …)` cannot eat it.
function(_bm_opt_as_string out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_as_string")
	if(ARGC LESS 2)
		_bm_log_message(COMPONENT DEBUG
			"_bm_opt_as_string: empty (ARGC=${ARGC})")
		set(${out_var} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_as_string")
		return()
	endif()
	set(_glue ";")
	string(JOIN "${_glue}" _flat ${ARGN})
	string(LENGTH "${_flat}" _n)
	string(FIND "${_flat}" ";" _semi)
	string(REPLACE ";" " | " _dump "${_flat}")
	_bm_log_message(COMPONENT DEBUG
		"_bm_opt_as_string: ARGC=${ARGC} len=${_n} semi=${_semi} [${_dump}]")
	set(${out_var} "${_flat}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_as_string")
endfunction()

## @brief Split an options string on `;` that are not inside `{…}`.
## @param[in]  options_string Raw `"KEY=value;KEY2={A=1;B=2}"` string.
##            A CMake list (function argument that contained `;`) is
##            accepted and re-joined first.
## @param[out] out_pairs      Parent-scope CMake list of tokens. Embedded `;`
##            inside `{…}` are stored as `__BM_SEMI__`.
## @note Brace depth counts nested `{` / `}`. Unbalanced `{` / `}` is FATAL.
##       Empty tokens are dropped. Values still must not contain a raw `;`
##       outside braces.
function(_bm_opt_split_pairs options_string out_pairs)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_split_pairs")
	_bm_opt_as_string(options_string ${options_string})
	string(LENGTH "${options_string}" _n)
	string(FIND "${options_string}" ";" _semi)
	string(REPLACE ";" " | " _dump "${options_string}")
	_bm_log_message(COMPONENT DEBUG
		"_bm_opt_split_pairs: in len=${_n} semi=${_semi} [${_dump}]")

	set(_segs ${options_string})
	set(_pairs "")
	set(_cur "")
	set(_depth 0)
	foreach(_seg IN LISTS _segs)
		string(REGEX REPLACE "[^{]" "" _opens "${_seg}")
		string(REGEX REPLACE "[^}]" "" _closes "${_seg}")
		string(LENGTH "${_opens}" _nopen)
		string(LENGTH "${_closes}" _nclose)
		if(_cur STREQUAL "")
			set(_cur "${_seg}")
		else()
			string(APPEND _cur "${_BM_OPT_SEMI}${_seg}")
		endif()
		math(EXPR _depth "${_depth} + ${_nopen} - ${_nclose}")
		if(_depth LESS 0)
			_bm_log_message(COMPONENT FATAL
				"Unmatched '}' in options string")
		endif()
		if(_depth EQUAL 0)
			string(STRIP "${_cur}" _tok)
			if(NOT _tok STREQUAL "")
				list(APPEND _pairs "${_tok}")
			endif()
			set(_cur "")
		endif()
	endforeach()
	if(NOT _depth EQUAL 0)
		_bm_log_message(COMPONENT FATAL
			"Unclosed '{' in options string")
	endif()
	string(STRIP "${_cur}" _tok)
	if(NOT _tok STREQUAL "")
		list(APPEND _pairs "${_tok}")
	endif()
	list(LENGTH _pairs _np)
	string(REPLACE ";" " | " _pdump "${_pairs}")
	_bm_log_message(COMPONENT DEBUG
		"_bm_opt_split_pairs: out n=${_np} [${_pdump}]")
	set(${out_pairs} "${_pairs}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_split_pairs")
endfunction()

## @brief Extract the interior of a `{…}` group.
## @param[in]  val        Stripped value that should be `{…}`.
## @param[out] out_inner  Text between the outermost braces (parent scope).
## @param[out] out_ok     TRUE if `val` is a single brace group.
function(_bm_opt_unwrap_brace val out_inner out_ok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_unwrap_brace")
	_bm_opt_as_string(_v ${val})
	string(STRIP "${_v}" _v)
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
	string(REPLACE ";" " | " _dump "${_inner}")
	_bm_log_message(COMPONENT DEBUG
		"_bm_opt_unwrap_brace: ok=${_ok} [${_dump}]")
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

	_bm_opt_as_string(pair ${pair})
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

	string(REPLACE ";" " | " _vdump "${_val}")
	_bm_log_message(COMPONENT DEBUG
		"_bm_opt_split_pair: ok=${_ok} key='${_key}' val=[${_vdump}]")
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
## @note Do not use this for `NOINSTALL` (`_bm_opt_parse_noinstall`).
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
