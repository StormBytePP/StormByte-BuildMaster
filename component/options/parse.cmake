# =============================================================================
# component/options/parse.cmake — KEY=value walker (indent / toolchain / flags)
# =============================================================================

## @brief Parse the optional `KEY=VALUE;…` optstr of `buildmaster_component`
##        and `buildmaster_meta`.
## @param[out] out_indent     Indent level (integer, default 0).
## @param[out] out_toolchain  Toolchain name (empty = inherit parent profile).
## @param[out] out_rename     TRUE/FALSE — normalize variant archive names
##            (default TRUE).
## @param[out] out_buildonly  TRUE/FALSE — build without installing to the shared
##            prefix (default FALSE). Artifacts live under the component BUILDDIR
##            only; RENAME runs in that tree after build.
## @param[out] out_whole      TRUE/FALSE — link produced statics with whole-archive
##            semantics (default FALSE). Only meaningful for static mode;
##            shared/headers → WARNING and ignored at materialize.
## @param[out] out_stripres   TRUE/FALSE — after RENAME, strip `.res` members from
##            static MSVC/clang-cl archives via lib/llvm-lib `/LIST` + `/REMOVE`
##            (default TRUE). Only meaningful for static mode; shared/headers
##            → WARNING and ignored. Non-MSVC toolchains are a silent no-op
##            at install time.
## @param[in]  options_string Optional `"KEY=value;KEY2=…"` string. Empty is valid.
##            `PC={…}`, `LINK={…}`, `LINKFLAGS={…}`, `GIT={…}` and `FILES={…}`
##            groups are allowed; `;` inside braces is not a pair break. A
##            trailing orphan `;` is allowed (dropped).
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit `=`.
##       Unknown keys → WARNING and ignored. `LINK_EXTRA` is removed; use
##       `LINK=` / `LINK={…}` for raw system linker names, `LINKFLAGS=` /
##       `LINKFLAGS={…}` for raw linker flags, and `buildmaster_link()` for BM
##       graph nodes. Values may contain `=` and spaces but not `;` outside `{…}`.
## @note `PC`, `LINK`, `LINKFLAGS`, `GIT`, `FILES` and `REPACK` are recognized
##       so they are not “unknown keys”. Details: `_bm_opt_parse_pc()`,
##       `_bm_opt_parse_link()`, `_bm_opt_parse_linkflags()`,
##       `_bm_opt_parse_git()`, `_bm_opt_parse_files()`,
##       `_bm_opt_parse_repack()`.
##       Meta + PC is FATAL in `buildmaster_meta`.
##       Meta + non-empty GIT is FATAL in `buildmaster_meta`.
##       Meta + FILES is FATAL in `buildmaster_meta`.
##       Meta + LINK / LINKFLAGS is accepted and applied INTERFACE on the
##       meta at materialize.
##       `REPACK` on a component is FATAL in `_bm_graph_create`.
##       `REPACK` on a meta merges member archives (see `buildmaster_meta`).
function(_bm_opt_parse out_indent out_toolchain out_rename
											out_buildonly out_whole out_stripres
											options_string)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse")
	set(_indent 0)
	set(_toolchain "")
	set(_rename TRUE)
	set(_buildonly FALSE)
	set(_whole FALSE)
	set(_stripres TRUE)

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

			if(_key STREQUAL "INDENT" OR _key STREQUAL "INDENT_LEVEL")
				if(_val MATCHES "^[0-9]+$")
					set(_indent "${_val}")
				else()
					_bm_log_message(COMPONENT WARNING
						"INDENT must be a non-negative integer, got '${_val}'")
				endif()
			elseif(_key STREQUAL "TOOLCHAIN")
				set(_toolchain "${_val}")
			elseif(_key STREQUAL "LINK")
				# parsed by _bm_opt_parse_link()
			elseif(_key STREQUAL "LINKFLAGS")
				# parsed by _bm_opt_parse_linkflags()
			elseif(_key STREQUAL "GIT")
				# parsed by _bm_opt_parse_git()
			elseif(_key STREQUAL "FILES")
				# parsed by _bm_opt_parse_files()
			elseif(_key STREQUAL "REPACK")
				# parsed by _bm_opt_parse_repack()
			elseif(_key STREQUAL "LINK_EXTRA")
				_bm_log_message(COMPONENT WARNING
					"LINK_EXTRA is removed; use LINK= / LINK={…} for syslibs, LINKFLAGS= / LINKFLAGS={…} for flags, buildmaster_link() for BM nodes (ignored)")
			elseif(_key STREQUAL "RENAME")
				_bm_opt_flag("${_val}" _rename)
			elseif(_key STREQUAL "BUILDONLY")
				_bm_opt_flag("${_val}" _buildonly)
			elseif(_key STREQUAL "WHOLE")
				_bm_opt_flag("${_val}" _whole)
			elseif(_key STREQUAL "STRIPRES")
				_bm_opt_flag("${_val}" _stripres)
			elseif(_key STREQUAL "PC")
				_bm_opt_unwrap_brace("${_val}" _pc_inner _pc_ok)
				if(NOT _pc_ok)
					_bm_log_message(COMPONENT FATAL
						"PC must be PC={VERSION=…;NAME=…;ENABLED=…} (got '${_val}')")
				endif()
			else()
				_bm_log_message(COMPONENT WARNING
					"Unknown component option '${_key}' (ignored)")
			endif()
		endforeach()
	endif()

	set(${out_indent} "${_indent}" PARENT_SCOPE)
	set(${out_toolchain} "${_toolchain}" PARENT_SCOPE)
	set(${out_rename} "${_rename}" PARENT_SCOPE)
	set(${out_buildonly} "${_buildonly}" PARENT_SCOPE)
	set(${out_whole} "${_whole}" PARENT_SCOPE)
	set(${out_stripres} "${_stripres}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse")
endfunction()

## @brief Parse `REPACK` / `REPACK=ON|OFF` from an options string.
## @param[in]  options_string Raw optstr (may be empty).
## @param[out] out_repack     Parent-scope TRUE if REPACK is enabled.
## @note Bare `REPACK`, `REPACK=` and `REPACK=ON` enable. `REPACK={…}` is
##       not a member list (members come from `buildmaster_meta_add`); a
##       brace group is treated as an unrecognized flag value → OFF + WARNING
##       via `_bm_opt_flag`.
function(_bm_opt_parse_repack options_string out_repack)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_repack")
	set(_repack FALSE)
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
			if(_key STREQUAL "REPACK")
				_bm_opt_flag("${_val}" _repack)
			endif()
		endforeach()
	endif()
	set(${out_repack} "${_repack}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_repack")
endfunction()
