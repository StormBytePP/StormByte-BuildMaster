# =============================================================================
# component/options.cmake — options string + library specs
# =============================================================================
# Loaded from component/helpers.cmake. Does not include backends.

## @brief Keys that may appear without '=' (flag form → enabled).
## @note RENAME, BUILDONLY and WHOLE accept `KEY`, `KEY=` and `KEY=ON|OFF`.
##       Other keys require `KEY=value`. Keep this list in sync with
##       buildmaster_parse_component_options().
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME;BUILDONLY;WHOLE")

## @brief Split one options token into key and value.
## @param[in]  pair     Raw token (`KEY=value`, `KEY=`, or `KEY` for flags).
## @param[out] out_key  Uppercase stripped key (parent scope).
## @param[out] out_val  Value after the first `=` (may be empty; may contain `=`).
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
## @param[in]  options_string Optional `"KEY=value;KEY2=…"` string. Empty is valid.
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit `=`.
##       Unknown keys → WARNING and ignored. `LINK_EXTRA` is removed; use
##       `component_link()`. Values may contain `=` and spaces but not `;`.
##       Extra positional arguments are not handled here (callers FATAL).
function(buildmaster_parse_component_options out_indent out_toolchain out_rename
											out_buildonly out_whole options_string)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_component_options")
	set(_indent 0)
	set(_toolchain "")
	set(_rename TRUE)
	set(_buildonly FALSE)
	set(_whole FALSE)

	if(NOT "${options_string}" STREQUAL "")
		string(REPLACE ";" "\n" _tmp "${options_string}")
		string(REPLACE "\n" ";" _pairs "${_tmp}")

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
			elseif(_key STREQUAL "LINK_EXTRA")
				buildmaster_message(COMPONENT WARNING
					"LINK_EXTRA is removed; use component_link() (ignored)")
			elseif(_key STREQUAL "RENAME")
				buildmaster_option_flag_enabled("${_val}" _rename)
			elseif(_key STREQUAL "BUILDONLY")
				buildmaster_option_flag_enabled("${_val}" _buildonly)
			elseif(_key STREQUAL "WHOLE")
				buildmaster_option_flag_enabled("${_val}" _whole)
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
## @param[in]  base_libdir  Root for archives (`BUILDMASTER_INSTALL_LIBDIR`, or the
##            component BUILDDIR when BUILDONLY).
## @param[out] names_var    List variable receiving the imported target name.
## @param[out] files_var    List variable receiving the archive/import path.
## @param[out] dlls_var     List variable receiving the MSVC DLL path (shared only).
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
			list(APPEND ${dlls_var}
				"${base_libdir}/${_bm_as_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
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
