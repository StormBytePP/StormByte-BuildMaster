# =============================================================================
# component/helpers.cmake — shared component factory (backend-agnostic)
# =============================================================================
# Public create_cmake_* / create_meson_* wrappers are included at the bottom
# from component/cmake and component/meson (also required for nested bootstrap
# that only include()s this file without add_subdirectory(component)).

## @brief Keys that may appear without '=' (flag form → enabled).
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME")

## @brief Split one options token into key and value.
## @param[in]  pair     Raw token (KEY=value, KEY=, or KEY for flags).
## @param[out] out_key  Uppercase stripped key (parent scope).
## @param[out] out_val  Value (may be empty).
## @param[out] out_ok   TRUE if the token is usable.
## @note Tokens without '=' are only accepted when the key is listed in
##       BUILDMASTER_COMPONENT_OPTION_FLAGS (e.g. RENAME ≡ RENAME=ON).
function(buildmaster_option_pair_split pair out_key out_val out_ok)
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
				message(WARNING
					"[BuildMaster] Option '${pair}' requires KEY=value form (ignored)")
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
endfunction()

## @brief Interpret a flag option value.
## @param[in]  val      Empty (flag form), or ON/OFF-style string.
## @param[out] out_bool Parent-scope TRUE/FALSE.
## @note Empty value means enabled (RENAME ≡ RENAME=ON ≡ RENAME=).
function(buildmaster_option_flag_enabled val out_bool)
	if("${val}" STREQUAL "")
		set(${out_bool} TRUE PARENT_SCOPE)
		return()
	endif()
	string(TOUPPER "${val}" _v)
	if(_v STREQUAL "1" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE" OR _v STREQUAL "YES")
		set(${out_bool} TRUE PARENT_SCOPE)
	elseif(_v STREQUAL "0" OR _v STREQUAL "OFF" OR _v STREQUAL "FALSE" OR _v STREQUAL "NO")
		set(${out_bool} FALSE PARENT_SCOPE)
	else()
		message(WARNING
			"[BuildMaster] Unrecognized flag value '${val}' (treated as OFF)")
		set(${out_bool} FALSE PARENT_SCOPE)
	endif()
endfunction()

## @brief Parse the optional KEY=VALUE;… options string used by create_*_component.
## @param[out] out_indent     Indent level (integer, default 0).
## @param[out] out_toolchain  Toolchain name (empty = inherit).
## @param[out] out_link_extra Raw LINK_EXTRA value (comma-separated), or empty.
## @param[out] out_rename     TRUE/FALSE — normalize variant installs (default TRUE).
## @param[in]  options_string Optional "KEY=value;KEY2=…" string.
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit '='.
##       LINK_EXTRA uses commas inside the value. Unknown keys → WARNING.
function(buildmaster_parse_component_options out_indent out_toolchain out_link_extra out_rename options_string)
	set(_indent 0)
	set(_toolchain "")
	set(_link_extra "")
	set(_rename TRUE)

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
					message(WARNING
						"[BuildMaster] INDENT must be a non-negative integer, got '${_val}'")
				endif()
			elseif(_key STREQUAL "TOOLCHAIN")
				set(_toolchain "${_val}")
			elseif(_key STREQUAL "LINK_EXTRA")
				if(_link_extra STREQUAL "")
					set(_link_extra "${_val}")
				else()
					set(_link_extra "${_link_extra},${_val}")
				endif()
			elseif(_key STREQUAL "RENAME")
				buildmaster_option_flag_enabled("${_val}" _rename)
			else()
				message(WARNING
					"[BuildMaster] Unknown component option '${_key}' (ignored)")
			endif()
		endforeach()
	endif()

	set(${out_indent} "${_indent}" PARENT_SCOPE)
	set(${out_toolchain} "${_toolchain}" PARENT_SCOPE)
	set(${out_link_extra} "${_link_extra}" PARENT_SCOPE)
	set(${out_rename} "${_rename}" PARENT_SCOPE)
endfunction()


## @brief Split a library spec into CMake target, library basename and libdir subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>`.
## @param[out] out_target  Imported CMake target name (`/` → `_`).
## @param[out] out_libname Library basename without prefix/suffix.
## @param[out] out_subdir  Directory relative to BUILDMASTER_INSTALL_LIBDIR, or empty.
function(buildmaster_parse_subcomponent spec out_target out_libname out_subdir)
	if("${spec}" STREQUAL "")
		message(FATAL_ERROR
			"[BuildMaster] buildmaster_parse_subcomponent: empty library spec")
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
		message(FATAL_ERROR
			"[BuildMaster] buildmaster_parse_subcomponent: missing library name in '${spec}'")
	endif()

	set(${out_target} "${_tgt}" PARENT_SCOPE)
	set(${out_libname} "${_name}" PARENT_SCOPE)
	set(${out_subdir} "${_dir}" PARENT_SCOPE)
endfunction()


## @brief Resolve one library spec into IMPORTED name + file path (+ MSVC DLL).
macro(buildmaster_append_library_spec library_mode spec names_var files_var dlls_var)
	buildmaster_parse_subcomponent("${spec}" _bm_as_tgt _bm_as_name _bm_as_subdir)
	list(APPEND ${names_var} "${_bm_as_tgt}")
	if("${library_mode}" STREQUAL "static")
		library_import_static_hint(_bm_as_path "${_bm_as_name}"
			"${BUILDMASTER_INSTALL_LIBDIR}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
	else()
		library_import_hint(_bm_as_path "${_bm_as_name}"
			"${BUILDMASTER_INSTALL_LIBDIR}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
		if(MSVC)
			list(APPEND ${dlls_var}
				"${BUILDMASTER_INSTALL_BINDIR}/${_bm_as_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		endif()
	endif()
endmacro()


## @brief Generate a per-component generator fragment and IMPORTED target wiring.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _build_system `cmake` or `meson`.
## @param[in] _produced Primary library specs this component installs.
## @param[in] _dependency Optional install-target dependency for dependant templates.
## @param[in] options_string Optional trailing "KEY=value;…" string.
##            Keys: INDENT/INDENT_LEVEL, TOOLCHAIN, LINK_EXTRA, RENAME (flag).
## @note RENAME defaults to ON: post-install normalize of variant archive names
##       before the OUTPUT contract check. RENAME=OFF disables it.
## @note Prefer create_cmake_* / create_meson_* wrappers; they call this.
## @note Fragment templates are read from BUILDMASTER_COMPONENT_TEMPLATEDIR.
function(create_component _library_create_file _component _component_title _srcdir _builddir
						_options _library_mode _build_system _produced _dependency)
	if(ARGC GREATER 11)
		message(FATAL_ERROR
			"[BuildMaster] create_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 10)
		set(_options_string "${ARGV10}")
	endif()

	buildmaster_parse_component_options(
		_indent_level _toolchain _link_extra _rename_on "${_options_string}")

	# Visible to create_*_stages configure_file for install_exec.cmake.in
	if(_library_mode STREQUAL "headers")
		set(_BM_RENAME_ENABLED "0")
	elseif(_rename_on)
		set(_BM_RENAME_ENABLED "1")
	else()
		set(_BM_RENAME_ENABLED "0")
	endif()

	string(TOLOWER "${_library_mode}" _library_mode)
	string(TOLOWER "${_build_system}" _build_system)

	if(NOT _library_mode STREQUAL "static"
			AND NOT _library_mode STREQUAL "shared"
			AND NOT _library_mode STREQUAL "headers")
		message(FATAL_ERROR
			"[BuildMaster] create_component: unknown library mode '${_library_mode}' "
			"(expected static, shared, or headers)")
	endif()

	if(NOT _build_system STREQUAL "cmake" AND NOT _build_system STREQUAL "meson")
		message(FATAL_ERROR
			"[BuildMaster] create_component: unknown build system '${_build_system}' "
			"(expected cmake or meson)")
	endif()

	set(_LIBRARY_COMPONENT_NAMES "")
	set(_LIBRARY_COMPONENT_FILES "")
	set(_LIBRARY_COMPONENT_DLL_FILES "")
	set(_output_libraries "")

	if(_library_mode STREQUAL "headers")
		set(_headers_stamp
			"${BUILDMASTER_INSTALL_INCLUDEDIR}/.bm_${_component}_headers.stamp")
		set(_output_libraries "${_headers_stamp}")
	else()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			buildmaster_append_library_spec(
				"${_library_mode}" "${_spec}"
				_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES _LIBRARY_COMPONENT_DLL_FILES)
		endforeach()

		if(NOT _link_extra STREQUAL "")
			string(REPLACE "," ";" _extra_specs "${_link_extra}")
			foreach(_spec IN LISTS _extra_specs)
				string(STRIP "${_spec}" _spec)
				if(_spec STREQUAL "")
					continue()
				endif()
				buildmaster_append_library_spec(
					"${_library_mode}" "${_spec}"
					_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES _LIBRARY_COMPONENT_DLL_FILES)
			endforeach()
		endif()

		set(_output_libraries "${_LIBRARY_COMPONENT_FILES}")
		if(MSVC AND _library_mode STREQUAL "shared")
			list(APPEND _output_libraries ${_LIBRARY_COMPONENT_DLL_FILES})
		endif()

		if(_LIBRARY_COMPONENT_FILES STREQUAL "")
			message(FATAL_ERROR
				"[BuildMaster] create_component '${_component}': "
				"static/shared mode requires at least one produced library spec")
		endif()
	endif()

	if(NOT _dependency STREQUAL "")
		set(_via_target "1")
	else()
		set(_via_target "0")
	endif()

	if(_build_system STREQUAL "cmake")
		create_cmake_stages(
			_LIBRARY_CONFIGURE_FILE
			_LIBRARY_BUILD_FILE
			_LIBRARY_INSTALL_FILE
			"${_component}"
			"${_component_title}"
			"${_srcdir}"
			"${_builddir}"
			"${_options}"
			"${_library_mode}"
			"${_output_libraries}"
			"${_indent_level}"
			"${_toolchain}"
			"${_via_target}"
		)
	else()
		create_meson_stages(
			_LIBRARY_CONFIGURE_FILE
			_LIBRARY_BUILD_FILE
			_LIBRARY_INSTALL_FILE
			"${_component}"
			"${_component_title}"
			"${_srcdir}"
			"${_builddir}"
			"${_options}"
			"${_library_mode}"
			"${_output_libraries}"
			"${_indent_level}"
			"${_toolchain}"
			"${_via_target}"
		)
	endif()

	if(DEFINED BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND)
		set(ENV_CMAKE_SILENT_COMMAND ${BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND})
	endif()

	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_CONFIGURE_TARGET "${_component}_configure")
	set(_LIBRARY_BUILD_TARGET "${_component}_build")
	set(_LIBRARY_DEPENDENCIES "${_dependency}")

	if(NOT _toolchain STREQUAL "")
		set(_LIBRARY_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain})")
	else()
		set(_LIBRARY_TOOLCHAIN_SUFFIX "")
	endif()

	if(NOT _dependency STREQUAL "")
		if(_library_mode STREQUAL "headers")
			set(_tpl "component_headers_dependant.cmake.in")
		elseif(_library_mode STREQUAL "shared")
			set(_tpl "component_shared_dependant.cmake.in")
		else()
			set(_tpl "component_static_dependant.cmake.in")
		endif()
	else()
		if(_library_mode STREQUAL "headers")
			set(_tpl "component_headers.cmake.in")
		elseif(_library_mode STREQUAL "shared")
			set(_tpl "component_shared.cmake.in")
		else()
			set(_tpl "component_static.cmake.in")
		endif()
	endif()

	sanitize_for_filename(_safe "${_component}")
	set(_LIBRARY_CREATE_FILE
		"${BUILDMASTER_SCRIPTS_COMPONENTDIR}/component_${_safe}.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_TEMPLATEDIR}/${_tpl}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Backend public wrappers
# ---------------------------------------------------------------------------
# Loaded here so nested BUILDMASTER_CONFIGURED bootstrap (include helpers only)
# still defines create_cmake_* / create_meson_*.
include("${CMAKE_CURRENT_LIST_DIR}/cmake/helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/meson/helpers.cmake")
