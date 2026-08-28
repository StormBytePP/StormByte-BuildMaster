# =============================================================================
# component/options.cmake — options string + library specs
# =============================================================================
# Loaded from component/helpers.cmake. Does not include backends.

## @brief Keys that may appear without '=' (flag form → enabled).
## @note RENAME, BUILDONLY, WHOLE, STRIPRES and PC accept `KEY`, `KEY=` and
##       `KEY=ON|OFF`. Other keys require `KEY=value`. Keep this list in
##       sync with buildmaster_parse_component_options().
## @note `PC` as a bare flag is accepted by the splitter so it is not treated
##       as an unknown token, but a `.pc` is only generated from `PC={…}`.
##       A bare `PC` / `PC=ON` without a brace group is FATAL.
## @note `PC={…}` is forbidden on meta components (no sources, no single
##       library contract). Membership can drag an unbounded set of leaves;
##       generating one `.pc` from that would pull Requires the author did
##       not choose and collide with upstream `.pc` files. create_meta_*
##       must FATAL if PC is present.
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME;BUILDONLY;WHOLE;STRIPRES;PC")

# CMake lists use ';' as the element separator. Tokens that contain ';'
# (PC={VERSION=1;NAME=x}) are stored with this stand-in so foreach(IN LISTS)
# does not re-split them. buildmaster_option_pair_split restores ';'.
set(_BM_OPT_SEMI "__BM_SEMI__")

## @brief Split an options string on `;` that are not inside `{…}`.
## @param[in]  options_string Raw `"KEY=value;KEY2={A=1;B=2}"` string.
## @param[out] out_pairs      Parent-scope CMake list of tokens. Embedded `;`
##            inside `{…}` are stored as `__BM_SEMI__`.
## @note Brace depth is not nested in v1 (`{` inside `{` still increments).
##       Unbalanced `{` / `}` is FATAL. Empty tokens are dropped.
##       Values still must not contain a raw `;` outside braces.
function(buildmaster_split_option_pairs options_string out_pairs)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_split_option_pairs")
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
					buildmaster_message(COMPONENT FATAL
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
		buildmaster_message(COMPONENT FATAL
			"Unclosed '{' in options string")
	endif()
	string(STRIP "${_cur}" _tok)
	if(NOT _tok STREQUAL "")
		string(REPLACE ";" "${_BM_OPT_SEMI}" _tok "${_tok}")
		list(APPEND _pairs "${_tok}")
	endif()
	set(${out_pairs} "${_pairs}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_split_option_pairs")
endfunction()

## @brief Extract the interior of a `{…}` group.
## @param[in]  val        Stripped value that should be `{…}`.
## @param[out] out_inner  Text between the outermost braces (parent scope).
## @param[out] out_ok     TRUE if `val` is a single brace group.
function(buildmaster_unwrap_brace_group val out_inner out_ok)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_unwrap_brace_group")
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_unwrap_brace_group")
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
function(buildmaster_option_pair_split pair out_key out_val out_ok)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_option_pair_split")
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
				buildmaster_message(COMPONENT WARNING
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_option_pair_split")
endfunction()

## @brief Interpret a flag option value as a CMake boolean.
## @param[in]  val      Empty (bare flag form), or an ON/OFF-style string.
## @param[out] out_bool Parent-scope TRUE or FALSE.
## @note Empty value means enabled (`RENAME` ≡ `RENAME=ON` ≡ `RENAME=`).
##       Accepted truthy: `1`, `ON`, `TRUE`, `YES` (case-insensitive).
##       Accepted falsy: `0`, `OFF`, `FALSE`, `NO`.
##       Any other non-empty value → WARNING and FALSE.
function(buildmaster_option_flag_enabled val out_bool)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_option_flag_enabled")
	if("${val}" STREQUAL "")
		set(${out_bool} TRUE PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_option_flag_enabled")
		return()
	endif()
	string(TOUPPER "${val}" _v)
	if(_v STREQUAL "1" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE" OR _v STREQUAL "YES")
		set(${out_bool} TRUE PARENT_SCOPE)
	elseif(_v STREQUAL "0" OR _v STREQUAL "OFF" OR _v STREQUAL "FALSE" OR _v STREQUAL "NO")
		set(${out_bool} FALSE PARENT_SCOPE)
	else()
		buildmaster_message(COMPONENT WARNING
			"Unrecognized flag value '${val}' (treated as OFF)")
		set(${out_bool} FALSE PARENT_SCOPE)
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_option_flag_enabled")
endfunction()

## @brief Parse `PC={VERSION=…;NAME=…;DESCRIPTION=…;ENABLED=…}` from an options string.
## @param[in]  options_string Same trailing string passed to create_*.
## @param[out] out_present    TRUE if a `PC` key was seen (bare or `PC={…}`).
## @param[out] out_enabled    TRUE if a `.pc` should be written.
## @param[out] out_name       Inner `NAME` or empty (caller defaults to produced).
## @param[out] out_version    Inner `VERSION` or empty.
## @param[out] out_description Inner `DESCRIPTION` or empty (caller defaults to title).
## @note The only valid generative form is `PC={…}`. Bare `PC` / `PC=ON` /
##       `PC=OFF` without braces is FATAL (use `PC={ENABLED=FALSE}` to opt out
##       while keeping the group).
## @note Missing VERSION is FATAL only when enabled. `ENABLED=FALSE` does not
##       require VERSION and does not write a file.
## @note `PC={…}` on a meta is FATAL at create_meta_* (unbounded Requires).
## @note If install already produced a `.pc` at the canonical path, writing
##       one is FATAL (do not clobber an upstream file). That check lives in
##       install_exec, not here.
## @note Unknown inner keys → WARNING and ignored.
function(buildmaster_parse_component_pc options_string out_present out_enabled
										out_name out_version out_description)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_component_pc")
	set(_present FALSE)
	set(_enabled FALSE)
	set(_name "")
	set(_version "")
	set(_description "")

	if(NOT "${options_string}" STREQUAL "")
		buildmaster_split_option_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			buildmaster_option_pair_split("${_pair}" _key _val _ok)
			if(NOT _ok)
				continue()
			endif()
			if(NOT _key STREQUAL "PC")
				continue()
			endif()
			set(_present TRUE)
			buildmaster_unwrap_brace_group("${_val}" _inner _brace_ok)
			if(NOT _brace_ok)
				buildmaster_message(COMPONENT FATAL
					"PC must be PC={VERSION=…;NAME=…;ENABLED=…} (got '${_val}')")
			endif()
			set(_enabled TRUE)
			buildmaster_split_option_pairs("${_inner}" _inner_pairs)
			foreach(_ip IN LISTS _inner_pairs)
				if(_ip STREQUAL "")
					continue()
				endif()
				buildmaster_option_pair_split("${_ip}" _ik _iv _iok)
				if(NOT _iok)
					continue()
				endif()
				if(_ik STREQUAL "VERSION")
					set(_version "${_iv}")
				elseif(_ik STREQUAL "NAME")
					set(_name "${_iv}")
				elseif(_ik STREQUAL "DESCRIPTION")
					set(_description "${_iv}")
				elseif(_ik STREQUAL "ENABLED")
					buildmaster_option_flag_enabled("${_iv}" _enabled)
				else()
					buildmaster_message(COMPONENT WARNING
						"Unknown PC sub-option '${_ik}' (ignored)")
				endif()
			endforeach()
		endforeach()
	endif()

	if(_present AND _enabled AND "${_version}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"PC={…} with ENABLED=TRUE requires VERSION")
	endif()

	set(${out_present} "${_present}" PARENT_SCOPE)
	set(${out_enabled} "${_enabled}" PARENT_SCOPE)
	set(${out_name} "${_name}" PARENT_SCOPE)
	set(${out_version} "${_version}" PARENT_SCOPE)
	set(${out_description} "${_description}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_parse_component_pc")
endfunction()

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
##       prefix. Use `component_link()` for BM graph nodes. A name that
##       collides with an existing TARGET may be resolved by CMake as that
##       target — do not use colliding names.
## @note One item: `LINK=shlwapi`. Several: `LINK={shlwapi;ws2_32}` — `;`
##       inside `{…}` is not a pair break. Bare `LINK` / `LINK=` is FATAL.
##       Several items without braces is FATAL. Empty tokens inside `{…}`
##       are dropped. This function does not interpret sibling keys.
function(buildmaster_parse_component_link options_string out_items)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_component_link")
	set(_items "")

	if(NOT "${options_string}" STREQUAL "")
		buildmaster_split_option_pairs("${options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			buildmaster_option_pair_split("${_pair}" _key _val _ok)
			if(NOT _ok OR NOT _key STREQUAL "LINK")
				continue()
			endif()
			if(_val STREQUAL "")
				buildmaster_message(COMPONENT FATAL
					"LINK requires LINK=<name> or LINK={name;name2} (bare LINK is invalid)")
			endif()
			buildmaster_unwrap_brace_group("${_val}" _inner _brace)
			if(_brace)
				if(NOT _inner STREQUAL "")
					buildmaster_split_option_pairs("${_inner}" _inner_pairs)
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
					buildmaster_message(COMPONENT FATAL
						"LINK with several items must be LINK={a;b} (got '${_val}')")
				endif()
				list(APPEND _items "${_val}")
			endif()
		endforeach()
	endif()

	if(_items)
		buildmaster_message(COMPONENT DEBUG "LINK items: ${_items}")
	endif()
	set(${out_items} "${_items}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_parse_component_link")
endfunction()

## @brief Parse the optional `KEY=VALUE;…` options string used by create_*_component.
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
##            `PC={…}` and `LINK={…}` groups are allowed; `;` inside braces is
##            not a pair break.
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit `=`.
##       Unknown keys → WARNING and ignored. `LINK_EXTRA` is removed; use
##       `LINK=` / `LINK={…}` for raw system linker names and `component_link()`
##       for BM graph nodes. Values may contain `=` and spaces but not `;`
##       outside `{…}`. Extra positional arguments are not handled here.
## @note `PC` and `LINK` are recognized so they are not “unknown keys”.
##       Generation details: `buildmaster_parse_component_pc()`,
##       `buildmaster_parse_component_link()`. Meta + PC is FATAL in
##       create_meta_*. Meta + LINK is WARNING ignored there.
function(buildmaster_parse_component_options out_indent out_toolchain out_rename
											out_buildonly out_whole out_stripres
											options_string)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_component_options")
	set(_indent 0)
	set(_toolchain "")
	set(_rename TRUE)
	set(_buildonly FALSE)
	set(_whole FALSE)
	set(_stripres TRUE)

	if(NOT "${options_string}" STREQUAL "")
		buildmaster_split_option_pairs("${options_string}" _pairs)

		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()

			buildmaster_option_pair_split("${_pair}" _key _val _ok)
			if(NOT _ok)
				continue()
			endif()

			if(_key STREQUAL "INDENT" OR _key STREQUAL "INDENT_LEVEL")
				if(_val MATCHES "^[0-9]+$")
					set(_indent "${_val}")
				else()
					buildmaster_message(COMPONENT WARNING
						"INDENT must be a non-negative integer, got '${_val}'")
				endif()
			elseif(_key STREQUAL "TOOLCHAIN")
				set(_toolchain "${_val}")
			elseif(_key STREQUAL "LINK")
				# parsed by buildmaster_parse_component_link()
			elseif(_key STREQUAL "LINK_EXTRA")
				buildmaster_message(COMPONENT WARNING
					"LINK_EXTRA is removed; use LINK= / LINK={…} for syslibs, component_link() for BM nodes (ignored)")
			elseif(_key STREQUAL "RENAME")
				buildmaster_option_flag_enabled("${_val}" _rename)
			elseif(_key STREQUAL "BUILDONLY")
				buildmaster_option_flag_enabled("${_val}" _buildonly)
			elseif(_key STREQUAL "WHOLE")
				buildmaster_option_flag_enabled("${_val}" _whole)
			elseif(_key STREQUAL "STRIPRES")
				buildmaster_option_flag_enabled("${_val}" _stripres)
			elseif(_key STREQUAL "PC")
				buildmaster_unwrap_brace_group("${_val}" _pc_inner _pc_ok)
				if(NOT _pc_ok)
					buildmaster_message(COMPONENT FATAL
						"PC must be PC={VERSION=…;NAME=…;ENABLED=…} (got '${_val}')")
				endif()
			else()
				buildmaster_message(COMPONENT WARNING
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_parse_component_options")
endfunction()

## @brief Split a library spec into CMake target, library basename and libdir subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>` (subdir may contain `/`).
## @param[out] out_target  Imported CMake target name (`/` replaced with `_`).
## @param[out] out_libname Library basename without prefix/suffix.
## @param[out] out_subdir  Directory relative to the library base dir, or empty.
## @note Empty spec or a trailing slash with no name is FATAL.
function(buildmaster_parse_subcomponent spec out_target out_libname out_subdir)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_subcomponent")
	if("${spec}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"buildmaster_parse_subcomponent: empty library spec")
	endif()

	string(FIND "${spec}" "/" _slash)
	if(_slash EQUAL -1)
		set(_tgt "${spec}")
		set(_name "${spec}")
		set(_dir "")
	else()
		get_filename_component(_name "${spec}" NAME)
		get_filename_component(_dir "${spec}" DIRECTORY)
		string(REPLACE "/" "_" _tgt "${spec}")
	endif()

	if("${_name}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"buildmaster_parse_subcomponent: missing library name in '${spec}'")
	endif()

	set(${out_target} "${_tgt}" PARENT_SCOPE)
	set(${out_libname} "${_name}" PARENT_SCOPE)
	set(${out_subdir} "${_dir}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_parse_subcomponent")
endfunction()

## @brief Resolve one library spec into IMPORTED name + file path (+ MSVC DLL).
## @param[in]  library_mode `static` or `shared`.
## @param[in]  spec         Library spec (`<name>` or `<subdir>/<name>`).
## @param[in]  base_libdir  Root for archives / import libs
##            (`BUILDMASTER_INSTALL_LIBDIR`, or the component BUILDDIR when
##            BUILDONLY).
## @param[out] names_var    List variable receiving the imported target name.
## @param[out] files_var    List variable receiving the archive/import path
##            under `base_libdir` (GNUInstallDirs ARCHIVE → LIBDIR).
## @param[out] dlls_var     List variable receiving the MSVC DLL path (shared
##            only). On an install prefix that is RUNTIME → BINDIR; BUILDONLY
##            keeps the DLL next to the other artifacts in BUILDDIR.
## @note Produced basenames keep the case of `spec` (`StormByte`, not
##       `stormbyte`).
## @note BUILDONLY must pass the component's own BUILDDIR — never the parent
##       install prefix or another component's build tree.
##       This is a macro so the caller's list variables are appended in place.
macro(buildmaster_append_library_spec library_mode spec base_libdir
									names_var files_var dlls_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_append_library_spec")
	buildmaster_parse_subcomponent("${spec}" _bm_as_tgt _bm_as_name _bm_as_subdir)
	list(APPEND ${names_var} "${_bm_as_tgt}")
	if("${library_mode}" STREQUAL "static")
		library_import_static_hint(_bm_as_path "${_bm_as_name}"
			"${base_libdir}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
	else()
		library_import_hint(_bm_as_path "${_bm_as_name}"
			"${base_libdir}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
		if(MSVC)
			# GNUInstallDirs: RUNTIME (DLL) → BINDIR, ARCHIVE (import .lib) → LIBDIR.
			# BUILDONLY keeps both artifacts under the component BUILDDIR.
			if("${base_libdir}" STREQUAL "${BUILDMASTER_INSTALL_LIBDIR}")
				set(_bm_as_dll_dir "${BUILDMASTER_INSTALL_BINDIR}")
			else()
				set(_bm_as_dll_dir "${base_libdir}")
			endif()
			if(NOT "${_bm_as_subdir}" STREQUAL "")
				set(_bm_as_dll_dir "${_bm_as_dll_dir}/${_bm_as_subdir}")
			endif()
			list(APPEND ${dlls_var}
				"${_bm_as_dll_dir}/${_bm_as_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		endif()
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_append_library_spec")
endmacro()

## @brief Build whole-archive linker items for a list of static archive paths.
## @param[out] _out_var Name of the parent-scope variable to receive the item list.
## @param[in]  ARGN     Absolute (or install-relative) static archive paths.
## @note One closed region per component on ELF (`--whole-archive` … `--no-whole-archive`);
##       per-archive `-Wl,-force_load,` on Apple; `-WHOLEARCHIVE:` on MSVC.
##       MSVC uses the `-WHOLEARCHIVE:` spelling so Ninja does not treat a leading
##       `/WHOLEARCHIVE:` token as a filesystem path.
function(_buildmaster_whole_archive_link_items _out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_whole_archive_link_items")
	set(_paths ${ARGN})
	set(_items "")
	if(NOT _paths)
		set(${_out_var} "" PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_whole_archive_link_items")
		return()
	endif()
	if(MSVC)
		foreach(_p IN LISTS _paths)
			list(APPEND _items "-WHOLEARCHIVE:${_p}")
		endforeach()
	elseif(APPLE)
		foreach(_p IN LISTS _paths)
			list(APPEND _items "-Wl,-force_load,${_p}")
		endforeach()
	else()
		list(APPEND _items "-Wl,--whole-archive")
		foreach(_p IN LISTS _paths)
			list(APPEND _items "${_p}")
		endforeach()
		list(APPEND _items "-Wl,--no-whole-archive")
	endif()
	set(${_out_var} "${_items}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_whole_archive_link_items")
endfunction()
