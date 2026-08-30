# =============================================================================
# component/materialize/fragment.cmake — collect outputs + write fragment
# =============================================================================

## @brief Fill produced names/files/dlls and install/build contract outputs.
## @param[in] _component Registered component id.
## @note Sets parent-scope: `_LIBRARY_COMPONENT_NAMES`, `_LIBRARY_COMPONENT_FILES`,
##       `_LIBRARY_COMPONENT_DLL_FILES`, `_output_libraries`, `_BM_RENAME_ENABLED`,
##       `_BM_BUILDONLY`, `_BM_STRIPRES_ENABLED`, `_BM_PC_*`, `_toolchain`.
## @note Does **not** export `_indent_level`. Group plan stamps
##       `BUILDMASTER_COMPONENT_<id>_INDENT`; the backend reads that
##       *after* this function. OPTSTR `INDENT=` is create-time (usually 0)
##       and must not overwrite the walk depth.
## @note BUILDONLY uses the component BUILDDIR as the library root; otherwise
##       `BUILDMASTER_INSTALL_LIBDIR`. Headers mode emits a stamp path, not libs.
## @note Extra `buildmaster_link` dests that are library specs (`<name>` or
##       `<subdir>/<name>`, not a component, meta, CMake target, or existing
##       file) are appended to the produced name/file lists so the fragment
##       can create IMPORTED targets. They are *not* added to stage `OUTPUT`:
##       `_bm_tools_*_stages` uses only the declared produced specs.
##       `write_fragment` attaches a Ninja file rule
##       (`OUTPUT <file>` `DEPENDS` `<id>_install`) for each extra.
## @note `_BM_STRIPRES_ENABLED` is `1` only for static mode when STRIPRES is on
##       (default ON). Shared/headers never strip; install_exec is a no-op there.
## @note `_BM_PC_*` comes from `_bm_pc_fill_vars` (tools/pkgconfig).
##       ENABLED is `1` only when `PC={…}` is on and not BUILDONLY (already FATAL
##       at _bm_graph_create).
function(_bm_materialize_collect_outputs _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_collect_outputs")
	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)

	_bm_opt_parse(
		_indent_ignored _toolchain _rename_on _buildonly _whole_ignored _stripres_on
		"${_options_string}")

	if(_buildonly)
		set(_BM_BUILDONLY "1")
		set(_base_libdir "${_builddir}")
	else()
		set(_BM_BUILDONLY "0")
		set(_base_libdir "${BUILDMASTER_INSTALL_LIBDIR}")
	endif()

	if(_library_mode STREQUAL "headers")
		set(_BM_RENAME_ENABLED "0")
	elseif(_rename_on)
		set(_BM_RENAME_ENABLED "1")
	else()
		set(_BM_RENAME_ENABLED "0")
	endif()

	if(_library_mode STREQUAL "static" AND _stripres_on)
		set(_BM_STRIPRES_ENABLED "1")
	else()
		set(_BM_STRIPRES_ENABLED "0")
	endif()

	_bm_pc_fill_vars("${_component}")

	set(_LIBRARY_COMPONENT_NAMES "")
	set(_LIBRARY_COMPONENT_FILES "")
	set(_LIBRARY_COMPONENT_DLL_FILES "")
	set(_output_libraries "")

	if(_library_mode STREQUAL "headers")
		if(_buildonly)
			set(_headers_stamp
				"${_builddir}/.bm_${_component}_headers.stamp")
		else()
			set(_headers_stamp
				"${BUILDMASTER_INSTALL_INCLUDEDIR}/.bm_${_component}_headers.stamp")
		endif()
		set(_output_libraries "${_headers_stamp}")
	else()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			_bm_opt_append_spec(
				"${_library_mode}" "${_spec}" "${_base_libdir}"
				_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES
				_LIBRARY_COMPONENT_DLL_FILES)
		endforeach()

		if(NOT _buildonly)
			get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
			get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
			if(_lsrcs)
				set(_li 0)
				foreach(_lsrc IN LISTS _lsrcs)
					list(GET _ldsts ${_li} _ldst)
					math(EXPR _li "${_li} + 1")
					if(NOT _lsrc STREQUAL "${_component}")
						continue()
					endif()
					_bm_graph_is_registered("${_ldst}" _ldst_comp)
					_bm_meta_is("${_ldst}" _ldst_meta)
					if(_ldst_comp OR _ldst_meta)
						continue()
					endif()
					if(TARGET "${_ldst}")
						continue()
					endif()
					if(EXISTS "${_ldst}" AND NOT IS_DIRECTORY "${_ldst}")
						continue()
					endif()
					_bm_opt_append_spec(
						"${_library_mode}" "${_ldst}" "${_base_libdir}"
						_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES
						_LIBRARY_COMPONENT_DLL_FILES)
				endforeach()
			endif()
		endif()

		set(_output_libraries "${_LIBRARY_COMPONENT_FILES}")
		if(MSVC AND _library_mode STREQUAL "shared")
			list(APPEND _output_libraries ${_LIBRARY_COMPONENT_DLL_FILES})
		endif()
	endif()

	set(_LIBRARY_COMPONENT_NAMES "${_LIBRARY_COMPONENT_NAMES}" PARENT_SCOPE)
	set(_LIBRARY_COMPONENT_FILES "${_LIBRARY_COMPONENT_FILES}" PARENT_SCOPE)
	set(_LIBRARY_COMPONENT_DLL_FILES "${_LIBRARY_COMPONENT_DLL_FILES}" PARENT_SCOPE)
	set(_output_libraries "${_output_libraries}" PARENT_SCOPE)
	set(_BM_RENAME_ENABLED "${_BM_RENAME_ENABLED}" PARENT_SCOPE)
	set(_BM_BUILDONLY "${_BM_BUILDONLY}" PARENT_SCOPE)
	set(_BM_STRIPRES_ENABLED "${_BM_STRIPRES_ENABLED}" PARENT_SCOPE)
	set(_BM_PC_ENABLED "${_BM_PC_ENABLED}" PARENT_SCOPE)
	set(_BM_PC_NAME "${_BM_PC_NAME}" PARENT_SCOPE)
	set(_BM_PC_VERSION "${_BM_PC_VERSION}" PARENT_SCOPE)
	set(_BM_PC_DESCRIPTION "${_BM_PC_DESCRIPTION}" PARENT_SCOPE)
	set(_BM_PC_LIBS "${_BM_PC_LIBS}" PARENT_SCOPE)
	set(_BM_PC_REQUIRES "${_BM_PC_REQUIRES}" PARENT_SCOPE)
	set(_BM_PC_CFLAGS "${_BM_PC_CFLAGS}" PARENT_SCOPE)
	set(_BM_PC_OUT "${_BM_PC_OUT}" PARENT_SCOPE)
	set(_toolchain "${_toolchain}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_collect_outputs")
endfunction()

## @brief configure_file + include the shared component fragment template.
## @param[in] _component Registered component id.
## @param[in] _deferred  TRUE → deferred template (configure at build time).
## @note Collects outputs, WHOLE, LINK and recorded dependencies, then
##       generates `component_<id>.cmake` under
##       `BUILDMASTER_SCRIPTS_COMPONENTDIR` and `include()`s it.
##       `<id>` is already an INTERFACE from `_bm_graph_create`; the fragment
##       attaches includes, IMPORTED archives, WHOLE and LINK.
##       LINKFLAGS is **not** applied here: `_bm_materialize_inject_linkflags`
##       already folded them into OPTIONS before stages ran.
## @note `_BM_LINK_ITEMS` is the CMake list stored on
##       `BUILDMASTER_COMPONENT_<id>_LINK` (empty string if unset). The
##       template applies it INTERFACE on `<id>` so consumers propagate
##       those raw names to the final artefact.
## @note `_BM_LINKFLAGS_ITEMS` is read only for DEBUG. The template does
##       not call `target_link_options`. An unused `@ONLY` substitution
##       is harmless if a leftover `@ _BM_LINKFLAGS_ITEMS @` remains.
## @note Library-spec `buildmaster_link` dests are folded into FILES by
##       `collect_outputs`. Stage `OUTPUT` is the declared produced specs
##       from `_bm_tools_*_stages`. After `include()`, each extra file
##       that is not in that list gets:
##         add_custom_command(OUTPUT <file> DEPENDS <id>_install
##                            COMMAND ${CMAKE_COMMAND} -E true)
##       The command does not write the file. `<id>_install` writes it as
##       a side effect of the nested install. The rule exists so Ninja has
##       a producer for `<file>` when a host target links the IMPORTED
##       location. Do not drop this because Make passed locally.
## @note STRIPRES / WHOLE ignored on a non-static mode are INFO. STRIPRES
##       INFO only when the user wrote the key (default is ON).
function(_bm_materialize_write_fragment _component _deferred)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_write_fragment")
	_bm_materialize_collect_outputs("${_component}")

	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	_bm_opt_parse(_il _toolchain _rn _bo _wh _sr "${_options_string}")
	if(_bo)
		set(_BM_BUILDONLY "1")
	else()
		set(_BM_BUILDONLY "0")
	endif()

	if(_sr AND NOT _library_mode STREQUAL "static")
		if("${_options_string}" MATCHES "[Ss][Tt][Rr][Ii][Pp][Rr][Ee][Ss]")
			_bm_log_message(COMPONENT INFO
				"STRIPRES ignored for '${_component}' (mode '${_library_mode}'; only static MSVC/clang-cl archives are stripped)")
		endif()
	endif()

	if(DEFINED BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND)
		set(ENV_CMAKE_SILENT_COMMAND ${BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND})
	endif()

	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_CONFIGURE_TARGET "${_component}_configure")
	set(_LIBRARY_BUILD_TARGET "${_component}_build")

	_bm_graph_dep_targets("${_component}" _LIBRARY_DEPENDENCIES)

	if(NOT _toolchain STREQUAL "")
		set(_LIBRARY_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain})")
	else()
		set(_LIBRARY_TOOLCHAIN_SUFFIX "")
	endif()

	set(_BM_WHOLE "0")
	set(_BM_WHOLE_LINK_ITEMS "")
	get_property(_whole_prop GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_WHOLE)
	if(_whole_prop)
		if(NOT _library_mode STREQUAL "static")
			_bm_log_message(COMPONENT INFO
				"WHOLE ignored for '${_component}' (mode '${_library_mode}'; only static is supported)")
		elseif(_LIBRARY_COMPONENT_FILES)
			set(_BM_WHOLE "1")
			_bm_opt_whole_items(_whole_list
				${_LIBRARY_COMPONENT_FILES})
			string(REPLACE ";" " " _BM_WHOLE_LINK_ITEMS "${_whole_list}")
		endif()
	endif()

	get_property(_BM_LINK_ITEMS GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_LINK)
	if(NOT _BM_LINK_ITEMS)
		set(_BM_LINK_ITEMS "")
	endif()
	if(_BM_LINK_ITEMS)
		_bm_log_message(COMPONENT DEBUG
			"${_component}: LINK (raw) → ${_BM_LINK_ITEMS}")
	endif()

	get_property(_BM_LINKFLAGS_ITEMS GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_LINKFLAGS)
	if(NOT _BM_LINKFLAGS_ITEMS)
		set(_BM_LINKFLAGS_ITEMS "")
	endif()
	if(_BM_LINKFLAGS_ITEMS)
		_bm_log_message(COMPONENT DEBUG
			"${_component}: LINKFLAGS (nested OPTIONS, not INTERFACE) → ${_BM_LINKFLAGS_ITEMS}")
	endif()

	if(_deferred)
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

	_bm_path_sanitize(_safe "${_component}")
	set(_LIBRARY_CREATE_FILE
		"${BUILDMASTER_SCRIPTS_COMPONENTDIR}/component_${_safe}.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_TEMPLATEDIR}/${_tpl}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)
	include("${_LIBRARY_CREATE_FILE}")

	if(NOT _library_mode STREQUAL "headers" AND TARGET "${_component}_install")
		set(_declared "")
		set(_base_libdir "${BUILDMASTER_INSTALL_LIBDIR}")
		if(_bo)
			get_property(_base_libdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)
		endif()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			set(_pn "")
			set(_pf "")
			set(_pd "")
			_bm_opt_append_spec(
				"${_library_mode}" "${_spec}" "${_base_libdir}" _pn _pf _pd)
			list(APPEND _declared ${_pf} ${_pd})
		endforeach()
		foreach(_file IN LISTS _LIBRARY_COMPONENT_FILES _LIBRARY_COMPONENT_DLL_FILES)
			if(_file STREQUAL "")
				continue()
			endif()
			list(FIND _declared "${_file}" _hit)
			if(NOT _hit EQUAL -1)
				continue()
			endif()
			add_custom_command(
				OUTPUT "${_file}"
				COMMAND "${CMAKE_COMMAND}" -E true
				DEPENDS "${_component}_install"
				COMMENT "[BuildMaster/Ninja    ]: Waiting for ${_component}_install to publish ${_file}"
				VERBATIM
			)
			_bm_log_message(COMPONENT DEBUG
				"Ninja file rule for spec-link '${_file}' via '${_component}_install'")
		endforeach()
	endif()

	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_NAMES
		"${_LIBRARY_COMPONENT_NAMES}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES
		"${_LIBRARY_COMPONENT_FILES}")
	_bm_log_message(COMPONENT DEBUG "Wrote fragment ${_LIBRARY_CREATE_FILE} (${_tpl})")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_write_fragment")
endfunction()
