# =============================================================================
# component/options/linkflags.cmake — LINKFLAGS= / LINKFLAGS={…} parser
# =============================================================================

## @brief Classify one LINKFLAGS `{…}` body into flags for this host.
## @param[in]  inner     Text inside the outermost `LINKFLAGS={…}`.
## @param[out] out_items Parent-scope list of flags that apply here.
## @note Platform keys: `WINDOWS` (WIN32), `LINUX` (CMAKE_SYSTEM_NAME Linux),
##       `MAC` (APPLE), `UNIX` (UNIX AND NOT WIN32 — Linux and macOS).
##       Matching groups are concatenated. A known group that does not apply
##       is skipped at INFO. `FOO={…}` with an unknown key is FATAL.
##       Tokens that are not `KEY={…}` are all-platform flags.
function(_bm_opt_parse_linkflags_group inner out_items)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_linkflags_group")
	set(_items "")

	_bm_opt_split_pairs("${inner}" _toks)
	foreach(_tok IN LISTS _toks)
		string(REPLACE "${_BM_OPT_SEMI}" ";" _tok "${_tok}")
		string(STRIP "${_tok}" _tok)
		if(_tok STREQUAL "")
			continue()
		endif()

		_bm_opt_unwrap_brace("${_tok}" _discard _is_bare_group)
		if(_is_bare_group)
			_bm_log_message(COMPONENT FATAL
				"LINKFLAGS group token '{…}' without a platform key (got '${_tok}')")
		endif()

		string(FIND "${_tok}" "=" _eq)
		set(_is_platform FALSE)
		set(_pkey "")
		set(_pval "")
		if(NOT _eq EQUAL -1)
			string(SUBSTRING "${_tok}" 0 ${_eq} _pkey)
			math(EXPR _vs "${_eq} + 1")
			string(SUBSTRING "${_tok}" ${_vs} -1 _pval)
			string(STRIP "${_pkey}" _pkey)
			string(TOUPPER "${_pkey}" _pkey)
			string(STRIP "${_pval}" _pval)
			_bm_opt_unwrap_brace("${_pval}" _pinner _pbrace)
			if(_pbrace)
				set(_is_platform TRUE)
			endif()
		endif()

		if(_is_platform)
			set(_known FALSE)
			set(_applies FALSE)
			if(_pkey STREQUAL "WINDOWS")
				set(_known TRUE)
				if(WIN32)
					set(_applies TRUE)
				endif()
			elseif(_pkey STREQUAL "LINUX")
				set(_known TRUE)
				if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
					set(_applies TRUE)
				endif()
			elseif(_pkey STREQUAL "MAC")
				set(_known TRUE)
				if(APPLE)
					set(_applies TRUE)
				endif()
			elseif(_pkey STREQUAL "UNIX")
				set(_known TRUE)
				if(UNIX AND NOT WIN32)
					set(_applies TRUE)
				endif()
			endif()
			if(NOT _known)
				_bm_log_message(COMPONENT FATAL
					"LINKFLAGS unknown platform key '${_pkey}' (want WINDOWS, LINUX, MAC, UNIX)")
			endif()
			if(NOT _applies)
				_bm_log_message(COMPONENT INFO
					"LINKFLAGS ${_pkey}={…} skipped on this host")
				continue()
			endif()
			if(_pinner STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pairs("${_pinner}" _flags)
			foreach(_f IN LISTS _flags)
				string(REPLACE "${_BM_OPT_SEMI}" ";" _f "${_f}")
				string(STRIP "${_f}" _f)
				if(NOT _f STREQUAL "")
					list(APPEND _items "${_f}")
				endif()
			endforeach()
		else()
			list(APPEND _items "${_tok}")
		endif()
	endforeach()

	set(${out_items} "${_items}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_linkflags_group")
endfunction()

## @brief Parse `LINKFLAGS=` / `LINKFLAGS={…}` from a component options string.
## @param[in]  options_string Trailing `"KEY=value;…"` of
##            `buildmaster_component` / `buildmaster_meta`.
## @param[out] out_items      Parent-scope CMake list of raw linker flags
##            selected for the current host (empty if omitted or nothing applies).
## @note Items are **external to BuildMaster**. They are raw linker flags
##       (`/FORCE:MULTIPLE`, `-Wl,-Bsymbolic`), not component ids, not metas,
##       not CMake targets, and not library specs. Use `LINK=` for system
##       library names and `buildmaster_link()` for BM graph nodes.
## @note On a concrete component they are folded into that id's nested
##       cmake / meson `OPTIONS` at finalize (`CMAKE_EXE_LINKER_FLAGS` /
##       `CMAKE_SHARED_LINKER_FLAGS` / `CMAKE_MODULE_LINKER_FLAGS`, or
##       `c_link_args` / `cpp_link_args`). They rewrite **that** third-party
##       link line only. They are never applied `INTERFACE` on `<id>` and
##       do not propagate to a parent that links the artefact
##       (Multimedia must not inherit FFmpeg's `-Wl,-Bsymbolic`).
## @note On `buildmaster_meta` the parser still fills the list so the
##       caller can WARNING + ignore. A meta has no nested link line.
## @note Forms:
##       - `LINKFLAGS=-Wl,-Bsymbolic` — one flag, every platform.
##       - `LINKFLAGS={-pthread;-Wl,-Bsymbolic}` — flags, every platform.
##       - `LINKFLAGS={WINDOWS={/FORCE:MULTIPLE};LINUX={-Wl,-Bsymbolic};MAC={};UNIX={-pthread}}`
##         Platform groups. Known keys: `WINDOWS`, `LINUX`, `MAC`, `UNIX`.
##         `UNIX` = Linux and macOS (not Windows). Matching groups are
##         concatenated. A group whose platform does not apply is dropped
##         at INFO. Empty group (`MAC={}`) adds nothing.
##       - Tokens inside `{…}` that are not `KEY={…}` are all-platform flags.
## @note Bare `LINKFLAGS` / `LINKFLAGS=` is FATAL. Several unbraced items
##       (`LINKFLAGS=a;b`) is FATAL. Unknown platform key `FOO={…}` is FATAL.
##       Empty tokens are dropped. This function does not interpret sibling keys.
function(_bm_opt_parse_linkflags options_string out_items)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_linkflags")
	set(_items "")

	if(NOT "${options_string}" STREQUAL "")
		_bm_opt_split_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pair("${_pair}" _key _val _ok)
			if(NOT _ok OR NOT _key STREQUAL "LINKFLAGS")
				continue()
			endif()
			if(_val STREQUAL "")
				_bm_log_message(COMPONENT FATAL
					"LINKFLAGS requires LINKFLAGS=<flag> or LINKFLAGS={…} (bare LINKFLAGS is invalid)")
			endif()
			_bm_opt_unwrap_brace("${_val}" _inner _brace)
			if(_brace)
				if(NOT _inner STREQUAL "")
					_bm_opt_parse_linkflags_group("${_inner}" _grp)
					list(APPEND _items ${_grp})
				endif()
			else()
				if(_val MATCHES ";")
					_bm_log_message(COMPONENT FATAL
						"LINKFLAGS with several items must be LINKFLAGS={a;b} (got '${_val}')")
				endif()
				list(APPEND _items "${_val}")
			endif()
		endforeach()
	endif()

	if(_items)
		_bm_log_message(COMPONENT DEBUG "LINKFLAGS items: ${_items}")
	endif()
	set(${out_items} "${_items}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_linkflags")
endfunction()
