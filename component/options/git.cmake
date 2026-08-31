# =============================================================================
# component/options/git.cmake — GIT={…} parser and apply
# =============================================================================

## @brief Parse `GIT={FETCH;SWITCH=…;RESET;PATCH=…;TITLE=…;ROOT=…}`.
## @param[in]  options_string Trailing `"KEY=value;…"`.
## @param[out] out_present    TRUE if a `GIT` key was seen.
## @param[out] out_fetch      TRUE if `FETCH` is enabled.
## @param[out] out_switch     Branch name, or empty.
## @param[out] out_reset      TRUE if `RESET` is enabled.
## @param[out] out_patches    Patch paths in declaration order.
## @param[out] out_title      Inner `TITLE`, or empty (caller defaults to id).
## @param[out] out_root       Inner `ROOT`, or empty (caller uses srcdir).
## @note Empty `GIT` / `GIT=` / `GIT={}` → WARNING, present TRUE, no ops.
##       Flush order is fixed: FETCH → SWITCH → RESET → PATCHs (declaration
##       order). Relative `PATCH=` is resolved by the caller against
##       `CMAKE_CURRENT_SOURCE_DIR`. Unknown inner keys → WARNING.
##       Empty `SWITCH=` or empty `PATCH=` or empty `ROOT=` → FATAL.
##       Meta + any GIT op is FATAL in `buildmaster_meta`.
## @note `ROOT=` is always a path under the component srcdir. A leading
##       `/` or drive letter is stripped (not an absolute filesystem path).
##       Omitted `ROOT` → work tree is srcdir. Git is demanded only when
##       a `GIT` key is present.
function(_bm_opt_parse_git options_string
		out_present out_fetch out_switch out_reset out_patches out_title
		out_root)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_git")
	set(_present FALSE)
	set(_fetch FALSE)
	set(_switch "")
	set(_reset FALSE)
	set(_patches "")
	set(_title "")
	set(_root "")

	if(NOT "${options_string}" STREQUAL "")
		_bm_opt_split_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pair("${_pair}" _key _val _ok)
			if(NOT _ok OR NOT _key STREQUAL "GIT")
				continue()
			endif()
			set(_present TRUE)
			_bm_opt_unwrap_brace("${_val}" _inner _brace)
			if(NOT _brace)
				set(_inner "${_val}")
			endif()
			if("${_inner}" STREQUAL "")
				_bm_log_message(COMPONENT WARNING
					"GIT={…} is empty (ignored)")
				continue()
			endif()
			_bm_opt_split_pairs("${_inner}" _inner_pairs)
			foreach(_ip IN LISTS _inner_pairs)
				if(_ip STREQUAL "")
					continue()
				endif()
				string(REPLACE "${_BM_OPT_SEMI}" ";" _ip "${_ip}")
				string(FIND "${_ip}" "=" _eq)
				if(_eq EQUAL -1)
					string(STRIP "${_ip}" _ik)
					string(TOUPPER "${_ik}" _ik)
					if(_ik STREQUAL "FETCH")
						set(_fetch TRUE)
					elseif(_ik STREQUAL "RESET")
						set(_reset TRUE)
					else()
						_bm_log_message(COMPONENT WARNING
							"Unknown GIT sub-option '${_ik}' (ignored)")
					endif()
					continue()
				endif()
				_bm_opt_split_pair("${_ip}" _ik _iv _iok)
				if(NOT _iok)
					continue()
				endif()
				if(_ik STREQUAL "FETCH")
					_bm_opt_flag("${_iv}" _fetch)
				elseif(_ik STREQUAL "RESET")
					_bm_opt_flag("${_iv}" _reset)
				elseif(_ik STREQUAL "SWITCH")
					if("${_iv}" STREQUAL "")
						_bm_log_message(COMPONENT FATAL
							"GIT SWITCH= requires a branch name")
					endif()
					set(_switch "${_iv}")
				elseif(_ik STREQUAL "PATCH")
					if("${_iv}" STREQUAL "")
						_bm_log_message(COMPONENT FATAL
							"GIT PATCH= requires a file path")
					endif()
					list(APPEND _patches "${_iv}")
				elseif(_ik STREQUAL "TITLE")
					set(_title "${_iv}")
				elseif(_ik STREQUAL "ROOT")
					if("${_iv}" STREQUAL "")
						_bm_log_message(COMPONENT FATAL
							"GIT ROOT= requires a directory")
					endif()
					set(_root "${_iv}")
				else()
					_bm_log_message(COMPONENT WARNING
						"Unknown GIT sub-option '${_ik}' (ignored)")
				endif()
			endforeach()
		endforeach()
	endif()

	if(_present)
		_bm_log_message(COMPONENT DEBUG
			"GIT fetch=${_fetch} switch='${_switch}' reset=${_reset} patches=${_patches} root='${_root}'")
		_bm_tools_demand_named(git)
	endif()

	set(${out_present} "${_present}" PARENT_SCOPE)
	set(${out_fetch} "${_fetch}" PARENT_SCOPE)
	set(${out_switch} "${_switch}" PARENT_SCOPE)
	set(${out_reset} "${_reset}" PARENT_SCOPE)
	set(${out_patches} "${_patches}" PARENT_SCOPE)
	set(${out_title} "${_title}" PARENT_SCOPE)
	set(${out_root} "${_root}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_git")
endfunction()

## @brief Turn `ROOT=` into a path relative to the component srcdir.
## @param[out] out_rel Parent-scope relative path (no leading `/` or drive).
## @param[in]  raw     Token from `ROOT=`.
## @note A value that looks absolute (`/src`, `C:/src`) is still relative
##       to srcdir: the root prefix is stripped. Empty after strip → FATAL.
function(_bm_comp_git_relroot out_rel raw)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_git_relroot")
	set(_r "${raw}")
	if(_r MATCHES "^[A-Za-z]:[/\\\\]")
		string(SUBSTRING "${_r}" 2 -1 _r)
	endif()
	string(REGEX REPLACE "^[/\\\\]+" "" _r "${_r}")
	if("${_r}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"GIT ROOT='${raw}' is empty after stripping a filesystem root prefix")
	endif()
	set(${out_rel} "${_r}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_git_relroot")
endfunction()

## @brief Resolve the GIT work tree under the component srcdir.
## @param[out] out_repo Parent-scope absolute work tree.
## @param[in]  srcdir   Component source directory.
## @param[in]  raw_root `ROOT=` token, or empty (→ srcdir).
## @note Order: normalize under srcdir → FATAL if the result is not
##       srcdir or a descendant (no existence probe) → FATAL if the
##       directory does not exist. `_bm_git_require_component_root`
##       runs later in `_bm_tools_git_*`.
function(_bm_comp_git_worktree out_repo srcdir raw_root)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_git_worktree")
	get_filename_component(_src "${srcdir}" ABSOLUTE)
	file(TO_CMAKE_PATH "${_src}" _src)
	if("${raw_root}" STREQUAL "")
		set(_repo "${_src}")
	else()
		_bm_comp_git_relroot(_rel "${raw_root}")
		get_filename_component(_repo "${_src}/${_rel}" ABSOLUTE)
		file(TO_CMAKE_PATH "${_repo}" _repo)
	endif()
	file(RELATIVE_PATH _inside "${_src}" "${_repo}")
	if(_inside MATCHES "^\\.\\.")
		_bm_log_message(COMPONENT FATAL
			"GIT ROOT escapes the component srcdir")
	endif()
	if(NOT IS_DIRECTORY "${_repo}")
		_bm_log_message(COMPONENT FATAL
			"GIT work tree is not a directory (${_repo})")
	endif()
	set(${out_repo} "${_repo}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_git_worktree")
endfunction()

## @brief Apply `GIT={…}` on a concrete component srcdir.
## @param[in] _id     Component id.
## @param[in] _title  Default TITLE when the group omits it.
## @param[in] _srcdir Component source directory.
## @param[in] _optstr Trailing options string (may omit GIT).
## @note No-op when GIT is absent. Empty group is already WARNING in parse.
##       PATCH paths: absolute unchanged; relative to
##       `CMAKE_CURRENT_SOURCE_DIR`. Missing file is FATAL.
##       `ROOT=` is always under `_srcdir` (leading `/` or drive stripped).
##       Escape above `_srcdir` is FATAL before any existence check.
##       Missing work tree is FATAL after the escape check.
##       The work tree is passed to `_bm_tools_git_*`, which refuse a
##       path that is not its own git root or that is the host repo.
##       Calls `_bm_tools_git_fetch` / `_switch` / `_reset` / `_patch` so
##       flush order stays FETCH → SWITCH → RESET → PATCH regardless of
##       declaration order inside the group (RESET/PATCH still flush
##       reset-then-patch).
function(_bm_comp_apply_git _id _title _srcdir _optstr)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_apply_git")
	_bm_opt_parse_git("${_optstr}" _present _fetch _switch _reset _patches _gtitle _groot)
	if(NOT _present)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_apply_git")
		return()
	endif()

	set(_t "${_gtitle}")
	if("${_t}" STREQUAL "")
		set(_t "${_title}")
	endif()
	if("${_t}" STREQUAL "")
		set(_t "${_id}")
	endif()

	_bm_comp_git_worktree(_repo "${_srcdir}" "${_groot}")

	if(_fetch)
		_bm_log_message(COMPONENT DEBUG "GIT FETCH ${_id} ${_repo}")
		_bm_tools_git_fetch("${_id}" "${_t}" "${_repo}")
	endif()
	if(NOT "${_switch}" STREQUAL "")
		_bm_log_message(COMPONENT DEBUG "GIT SWITCH ${_id} ${_switch} ${_repo}")
		_bm_tools_git_switch("${_id}" "${_t}" "${_repo}" "${_switch}")
	endif()
	if(_reset)
		_bm_log_message(COMPONENT DEBUG "GIT RESET ${_id} ${_repo}")
		_bm_tools_git_reset("${_id}" "${_t}" "${_repo}")
	endif()
	foreach(_p IN LISTS _patches)
		if(IS_ABSOLUTE "${_p}")
			set(_abs "${_p}")
		else()
			set(_abs "${CMAKE_CURRENT_SOURCE_DIR}/${_p}")
		endif()
		get_filename_component(_abs "${_abs}" ABSOLUTE)
		if(NOT EXISTS "${_abs}")
			_bm_log_message(COMPONENT FATAL
				"GIT PATCH='${_p}' not found (${_abs})")
		endif()
		_bm_log_message(COMPONENT DEBUG "GIT PATCH ${_id} ${_abs}")
		_bm_tools_git_patch("${_id}" "${_t}" "${_repo}" "${_abs}")
	endforeach()

	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_apply_git")
endfunction()
