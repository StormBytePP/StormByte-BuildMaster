# =============================================================================
# component/options/parse.cmake — KEY=value walker (indent / toolchain / flags)
# =============================================================================

## @brief Parse the optional `KEY=VALUE;…` optstr of `buildmaster_component`
##        and `buildmaster_meta`.
## @param[out] out_indent     Always 0. `INDENT=` / `INDENT_LEVEL=` is WARNING
##            and ignored; groups stamp indent at finalize.
## @param[out] out_toolchain  Toolchain name (empty = inherit parent profile).
## @param[out] out_rename     TRUE/FALSE — normalize variant archive names
##            (default TRUE).
## @param[out] out_noinstall  TRUE/FALSE — configure/build without publishing
##            to the shared prefix (default FALSE). Artifacts stay under the
##            component BUILDDIR; RENAME runs in that tree after build.
## @param[out] out_whole      TRUE/FALSE — link produced statics with whole-archive
##            semantics (default FALSE). Only meaningful for static mode;
##            shared/headers → WARNING and ignored at materialize.
## @param[out] out_stripres   TRUE/FALSE — after RENAME, strip `.res` members from
##            static MSVC/clang-cl archives via lib/llvm-lib `/LIST` + `/REMOVE`
##            (default TRUE). Only meaningful for static mode; shared/headers
##            → WARNING and ignored. Non-MSVC toolchains are a silent no-op
##            at install time.
## @param[in]  options_string Optional `"KEY=value;KEY2=…"` string. Empty is valid.
##            `PC={…}`, `LINK={…}`, `LINKFLAGS={…}`, `GIT={…}`, `FILES={…}`
##            and `REQUIRE_TOOL={…}` groups are allowed; `;` inside braces is
##            not a pair break. A trailing orphan `;` is allowed (dropped).
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit `=`.
##       Unknown keys → WARNING and ignored. `LINK_EXTRA` is removed; use
##       `LINK=` / `LINK={…}` for raw system linker names, `LINKFLAGS=` /
##       `LINKFLAGS={…}` for raw linker flags, and `buildmaster_link()` for BM
##       graph nodes.
## @note `BUILDONLY` is removed. Use `NOINSTALL`. The old key is FATAL.
## @note `NOINSTALL` (bare) enables with no message. `NOINSTALL=` and
##       truthy `NOINSTALL=ON|TRUE|1|YES` enable with WARNING
##       (`write NOINSTALL, not NOINSTALL=…`). Falsy values are FATAL
##       (`omit the key to install`). Any other value is FATAL.
## @note `INDENT` / `INDENT_LEVEL` is ignored. Use `buildmaster_group()`.
function(_bm_opt_parse out_indent out_toolchain out_rename
											out_noinstall out_whole out_stripres
											options_string)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse")
	set(_indent 0)
	set(_toolchain "")
	set(_rename TRUE)
	set(_noinstall FALSE)
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
				_bm_log_message(COMPONENT WARNING
					"INDENT= is ignored; put the component in a buildmaster_group() so the outline stamps indent")
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
			elseif(_key STREQUAL "REQUIRE_TOOL")
				# parsed by _bm_opt_parse_require_tool()
			elseif(_key STREQUAL "BACKEND")
				# parsed by _bm_opt_parse_backend()
			elseif(_key STREQUAL "SOURCE")
				# parsed by _bm_opt_parse_source()
			elseif(_key STREQUAL "LINK_EXTRA")
				_bm_log_message(COMPONENT WARNING
					"LINK_EXTRA is removed; use LINK= / LINK={…} for syslibs, LINKFLAGS= / LINKFLAGS={…} for flags, buildmaster_link() for BM nodes (ignored)")
			elseif(_key STREQUAL "RENAME")
				_bm_opt_flag("${_val}" _rename)
			elseif(_key STREQUAL "BUILDONLY")
				_bm_log_message(COMPONENT FATAL
					"BUILDONLY is removed; use NOINSTALL")
			elseif(_key STREQUAL "NOINSTALL")
				string(REPLACE "${_BM_OPT_SEMI}" ";" _npair "${_pair}")
				string(FIND "${_npair}" "=" _neq)
				if(_neq EQUAL -1)
					set(_noinstall TRUE)
				else()
					_bm_opt_parse_noinstall("${_val}" _noinstall)
				endif()
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
	set(${out_noinstall} "${_noinstall}" PARENT_SCOPE)
	set(${out_whole} "${_whole}" PARENT_SCOPE)
	set(${out_stripres} "${_stripres}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse")
endfunction()

## @brief Interpret `NOINSTALL=<val>` (the bare token is handled by the caller).
## @param[in]  val      Text after `=`. Empty means `NOINSTALL=`.
## @param[out] out_bool Parent-scope TRUE when the flag is accepted.
## @note Empty and truthy → TRUE + WARNING
##       (`write NOINSTALL, not NOINSTALL=…`).
##       Falsy → FATAL (`omit the key to install`).
##       Any other value → FATAL.
function(_bm_opt_parse_noinstall val out_bool)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_noinstall")
	if("${val}" STREQUAL "")
		_bm_log_message(COMPONENT WARNING
			"NOINSTALL is a flag; write NOINSTALL, not NOINSTALL=…")
		set(${out_bool} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_noinstall")
		return()
	endif()
	string(TOUPPER "${val}" _v)
	if(_v STREQUAL "1" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE" OR _v STREQUAL "YES")
		_bm_log_message(COMPONENT WARNING
			"NOINSTALL is a flag; write NOINSTALL, not NOINSTALL=…")
		set(${out_bool} TRUE PARENT_SCOPE)
	elseif(_v STREQUAL "0" OR _v STREQUAL "OFF" OR _v STREQUAL "FALSE" OR _v STREQUAL "NO")
		_bm_log_message(COMPONENT FATAL
			"NOINSTALL cannot be turned off; omit the key to install")
	else()
		_bm_log_message(COMPONENT FATAL
			"NOINSTALL: invalid value '${val}' (write NOINSTALL, or omit the key)")
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_noinstall")
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
