# =============================================================================
# component/helpers.cmake
# =============================================================================

## @brief Parse the optional KEY=VALUE;KEY=VALUE options string used by
##        create_*_component family.
## @param[out] out_indent     Parent-scope variable receiving the indent level
##                            (integer, default 0).
## @param[out] out_toolchain  Parent-scope variable receiving the toolchain name
##                            (empty string means inherit parent).
## @param[out] out_link_extra Parent-scope variable receiving the raw LINK_EXTRA
##                            value (comma-separated specs), or empty.
## @param[in]  options_string Optional string of the form
##                            "KEY=value;KEY2=value with spaces".
##                            Only the first '=' in each pair separates key from
##                            value. Keys are matched case-insensitively but
##                            stored uppercase. Values may contain '=' and
##                            spaces but must not contain ';'.
## @note Unknown keys produce a WARNING and are ignored. Empty values are
##       legal (e.g. TOOLCHAIN= means inherit). LINK_EXTRA values use ','
##       to separate library specs (';' would start another option pair).
function(buildmaster_parse_component_options out_indent out_toolchain out_link_extra options_string)
	set(_indent 0)
	set(_toolchain "")
	set(_link_extra "")

	if(NOT "${options_string}" STREQUAL "")
		string(REPLACE ";" "\n" _tmp "${options_string}")
		string(REPLACE "\n" ";" _pairs "${_tmp}")

		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()

			# Only the first '=' is the separator
			string(FIND "${_pair}" "=" _eq_pos)
			if(_eq_pos EQUAL -1)
				message(WARNING
					"[BuildMaster] Ignoring malformed option (no '='): '${_pair}'")
				continue()
			endif()

			string(SUBSTRING "${_pair}" 0 ${_eq_pos} _key)
			math(EXPR _val_start "${_eq_pos} + 1")
			string(SUBSTRING "${_pair}" ${_val_start} -1 _val)

			string(STRIP "${_key}" _key)
			string(TOUPPER "${_key}" _key)
			string(STRIP "${_val}" _val)

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
			else()
				message(WARNING
					"[BuildMaster] Unknown component option '${_key}' (ignored)")
			endif()
		endforeach()
	endif()

	set(${out_indent} "${_indent}" PARENT_SCOPE)
	set(${out_toolchain} "${_toolchain}" PARENT_SCOPE)
	set(${out_link_extra} "${_link_extra}" PARENT_SCOPE)
endfunction()


## @brief Split a subcomponent spec into CMake target, library basename and libdir subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>`
##                         (example: `recursive/cmake/nestlib`).
## @param[out] out_target  Imported CMake target name (`/` replaced by `_`).
## @param[out] out_libname Library basename without prefix/suffix (`nestlib`).
## @param[out] out_subdir  Directory relative to BUILDMASTER_INSTALL_LIBDIR
##                         (`recursive/cmake`), or empty for the legacy layout.
## @note CMake target names cannot contain `/`. The imported target is
##       therefore `recursive_cmake_nestlib` while the file is
##       `${BUILDMASTER_INSTALL_LIBDIR}/recursive/cmake/libnestlib.a`.
function(buildmaster_parse_subcomponent spec out_target out_libname out_subdir)
	if("${spec}" STREQUAL "")
		message(FATAL_ERROR
			"[BuildMaster] buildmaster_parse_subcomponent: empty subcomponent spec")
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
## @param[in]  library_mode `static` or `shared`.
## @param[in]  spec         `<name>` or `<subdir>/<name>`.
## @param[in]  names_var    List variable (caller scope) receiving target names.
## @param[in]  files_var    List variable receiving archive / import-lib paths.
## @param[in]  dlls_var     List variable receiving MSVC DLL paths (shared only).
## @note Appends to the three list variables in the caller scope (macro).
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
## @param[in] _produced List of library specs this component **owns** as primary
##            install artefacts (ignored for headers). Each entry is `<name>`
##            or `<subdir>/<name>`. At least one is required for static/shared.
## @param[in] _dependency Optional install-target dependency for dependant templates.
## @param[in] options_string Optional (last argument) string of the form
##            "KEY=value;KEY2=value with spaces". Supported keys:
##              INDENT / INDENT_LEVEL – indentation level for STATUS messages
##              TOOLCHAIN             – BuildMaster toolchain name (empty = inherit)
##              LINK_EXTRA            – extra library specs (comma-separated) also
##                                      wired as IMPORTED and listed on the install
##                                      stage OUTPUT so Ninja tracks nested installs;
##                                      not a substitute for add_dependencies on a
##                                      sibling component install
##            Unknown keys produce a WARNING. Values may contain '=' and spaces
##            but must not contain ';'. Only the first '=' separates key from value.
## @note Extra positional arguments beyond the options string cause FATAL_ERROR.
function(create_component _library_create_file _component _component_title _srcdir _builddir
						_options _library_mode _build_system _produced _dependency)
	# Fixed: 10 arguments (indices 0-9). Optional options_string is ARGV10.
	if(ARGC GREATER 11)
		message(FATAL_ERROR
			"[BuildMaster] create_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 10)
		set(_options_string "${ARGV10}")
	endif()

	buildmaster_parse_component_options(_indent_level _toolchain _link_extra "${_options_string}")

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

	# ---- IMPORTED (produced + LINK_EXTRA) and install OUTPUT (same file list) ----
	# LINK_EXTRA paths stay on OUTPUT so Ninja has a producer when nested
	# BuildMaster installs them during this component's install stage.
	# install_exec never writes empty .a/.lib stamps.
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

	# Dependants: configure runs under a custom target → suppress hierarchical STATUS
	if(NOT _dependency STREQUAL "")
		set(_via_target "1")
	else()
		set(_via_target "0")
	endif()

	# ---- generate configure / build / install stage scripts ----
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

	# Prefer BM_COMPONENT_ENV_* from stages when set (per-component toolchain)
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

	# ---- pick fragment template ----
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
		"${BUILDMASTER_COMPONENT_SRCDIR}/${_tpl}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()


## @brief CMake component wrapper.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs this component installs
##            (`<name>` or `<subdir>/<name>`). Extra link specs: LINK_EXTRA=.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys (including LINK_EXTRA).
function(create_cmake_component _library_create_file _component _component_title
								_srcdir _builddir _options _library_mode _produced)
	if(ARGC GREATER 9)
		message(FATAL_ERROR
			"[BuildMaster] create_cmake_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 8)
		set(_options_string "${ARGV8}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"cmake"
		"${_produced}"
		""
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Meson component wrapper.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs this component installs
##            (`<name>` or `<subdir>/<name>`). Extra link specs: LINK_EXTRA=.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys (including LINK_EXTRA).
function(create_meson_component _library_create_file _component _component_title
								_srcdir _builddir _options _library_mode _produced)
	if(ARGC GREATER 9)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 8)
		set(_options_string "${ARGV8}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"meson"
		"${_produced}"
		""
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Dependant CMake component wrapper.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs this component installs
##            (`<name>` or `<subdir>/<name>`). Extra link specs: LINK_EXTRA=.
## @param[in] _dependency Install-target dependency.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys (including LINK_EXTRA).
function(create_cmake_dependant_component _library_create_file _component _component_title
										_srcdir _builddir _options _library_mode
										_produced _dependency)
	if(ARGC GREATER 10)
		message(FATAL_ERROR
			"[BuildMaster] create_cmake_dependant_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 9)
		set(_options_string "${ARGV9}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"cmake"
		"${_produced}"
		"${_dependency}"
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Dependant Meson component wrapper.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs this component installs
##            (`<name>` or `<subdir>/<name>`). Extra link specs: LINK_EXTRA=.
## @param[in] _dependency Install-target dependency.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys (including LINK_EXTRA).
function(create_meson_dependant_component _library_create_file _component _component_title
										_srcdir _builddir _options _library_mode
										_produced _dependency)
	if(ARGC GREATER 10)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_dependant_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 9)
		set(_options_string "${ARGV9}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"meson"
		"${_produced}"
		"${_dependency}"
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Header-only CMake component.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_cmake_headers_component _library_create_file _component _component_title
										_srcdir _builddir _options)
	if(ARGC GREATER 7)
		message(FATAL_ERROR
			"[BuildMaster] create_cmake_headers_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 6)
		set(_options_string "${ARGV6}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"cmake"
		""
		""
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Dependant header-only CMake component.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _dependency Install-target dependency.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_cmake_headers_dependant_component _library_create_file _component
												_component_title _srcdir _builddir
												_options _dependency)
	if(ARGC GREATER 8)
		message(FATAL_ERROR
			"[BuildMaster] create_cmake_headers_dependant_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 7)
		set(_options_string "${ARGV7}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"cmake"
		""
		"${_dependency}"
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Header-only Meson component.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_meson_headers_component _library_create_file _component _component_title
										_srcdir _builddir _options)
	if(ARGC GREATER 7)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_headers_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 6)
		set(_options_string "${ARGV6}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"meson"
		""
		""
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Dependant header-only Meson component.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _dependency Install-target dependency.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_meson_headers_dependant_component _library_create_file _component
												_component_title _srcdir _builddir
												_options _dependency)
	if(ARGC GREATER 8)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_headers_dependant_component: too many arguments "
			"(expected at most one options string).")
	endif()

	set(_options_string "")
	if(ARGC GREATER 7)
		set(_options_string "${ARGV7}")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"meson"
		""
		"${_dependency}"
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()
