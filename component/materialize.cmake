# =============================================================================
# component/materialize.cmake — fragment emit, links, deferred finalize
# =============================================================================
# Backends call _buildmaster_component_collect_outputs / write_fragment.
# Finalize is scheduled by _buildmaster_component_defer_arm (graph.cmake).

## @brief Fill produced names/files/dlls and install/build contract outputs.
## @param[in] _component Registered component id.
## @note Sets parent-scope: `_LIBRARY_COMPONENT_NAMES`, `_LIBRARY_COMPONENT_FILES`,
##       `_LIBRARY_COMPONENT_DLL_FILES`, `_output_libraries`, `_BM_RENAME_ENABLED`,
##       `_BM_BUILDONLY`, `_BM_STRIPRES_ENABLED`, `_BM_PC_*`, `_indent_level`,
##       `_toolchain`.
## @note BUILDONLY uses the component BUILDDIR as the library root; otherwise
##       `BUILDMASTER_INSTALL_LIBDIR`. Headers mode emits a stamp path, not libs.
## @note Extra `component_link` dests that are raw library specs (not components,
##       metas, targets, or existing files) are appended to the produced lists
##       so install BYPRODUCTS stay complete.
## @note `_BM_STRIPRES_ENABLED` is `1` only for static mode when STRIPRES is on
##       (default ON). Shared/headers never strip; install_exec is a no-op there.
## @note `_BM_PC_*` comes from `_buildmaster_component_fill_pc_vars` (tools/pkgconfig).
##       ENABLED is `1` only when `PC={…}` is on and not BUILDONLY (already FATAL
##       at create_component).
function(_buildmaster_component_collect_outputs _component)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_collect_outputs")
	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)

	buildmaster_parse_component_options(
		_indent_level _toolchain _rename_on _buildonly _whole_ignored _stripres_on
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

	_buildmaster_component_fill_pc_vars("${_component}")

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
			buildmaster_append_library_spec(
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
					_buildmaster_component_is_registered("${_ldst}" _ldst_comp)
					_buildmaster_meta_is("${_ldst}" _ldst_meta)
					if(_ldst_comp OR _ldst_meta)
						continue()
					endif()
					if(TARGET "${_ldst}")
						continue()
					endif()
					if(EXISTS "${_ldst}" AND NOT IS_DIRECTORY "${_ldst}")
						continue()
					endif()
					buildmaster_append_library_spec(
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
	set(_indent_level "${_indent_level}" PARENT_SCOPE)
	set(_toolchain "${_toolchain}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_collect_outputs")
endfunction()

## @brief configure_file + include the shared component fragment template.
## @param[in] _component Registered component id.
## @param[in] _deferred  TRUE → dependant template (configure at build time).
## @note Collects outputs, WHOLE link items, and recorded dependencies, then
##       generates `component_<id>.cmake` under `BUILDMASTER_SCRIPTS_COMPONENTDIR`
##       and `include()`s it so IMPORTED / INTERFACE targets exist immediately.
## @note Stores produced names/files as GLOBAL properties for later link apply.
function(_buildmaster_component_write_fragment _component _deferred)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_write_fragment")
	# Collect in this scope: materialize locals are not visible here.
	_buildmaster_component_collect_outputs("${_component}")

	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	buildmaster_parse_component_options(_il _toolchain _rn _bo _wh _sr "${_options_string}")
	if(_bo)
		set(_BM_BUILDONLY "1")
	else()
		set(_BM_BUILDONLY "0")
	endif()

	if(_sr AND NOT _library_mode STREQUAL "static")
		buildmaster_message(COMPONENT WARNING
			"STRIPRES ignored for '${_component}' (mode '${_library_mode}'; only static MSVC/clang-cl archives are stripped)")
	endif()

	if(DEFINED BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND)
		set(ENV_CMAKE_SILENT_COMMAND ${BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND})
	endif()

	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_CONFIGURE_TARGET "${_component}_configure")
	set(_LIBRARY_BUILD_TARGET "${_component}_build")

	_buildmaster_component_dep_targets("${_component}" _LIBRARY_DEPENDENCIES)

	if(NOT _toolchain STREQUAL "")
		set(_LIBRARY_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain})")
	else()
		set(_LIBRARY_TOOLCHAIN_SUFFIX "")
	endif()

	# WHOLE → one closed whole-archive region for all produced static paths
	set(_BM_WHOLE "0")
	set(_BM_WHOLE_LINK_ITEMS "")
	get_property(_whole_prop GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_WHOLE)
	if(_whole_prop)
		if(NOT _library_mode STREQUAL "static")
			buildmaster_message(COMPONENT WARNING
				"WHOLE ignored for '${_component}' (mode '${_library_mode}'; only static is supported)")
		elseif(_LIBRARY_COMPONENT_FILES)
			set(_BM_WHOLE "1")
			_buildmaster_whole_archive_link_items(_whole_list
				${_LIBRARY_COMPONENT_FILES})
			string(REPLACE ";" " " _BM_WHOLE_LINK_ITEMS "${_whole_list}")
		endif()
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

	sanitize_for_filename(_safe "${_component}")
	set(_LIBRARY_CREATE_FILE
		"${BUILDMASTER_SCRIPTS_COMPONENTDIR}/component_${_safe}.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_TEMPLATEDIR}/${_tpl}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)
	include("${_LIBRARY_CREATE_FILE}")

	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_NAMES
		"${_LIBRARY_COMPONENT_NAMES}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES
		"${_LIBRARY_COMPONENT_FILES}")
	buildmaster_message(COMPONENT DEBUG "Wrote fragment ${_LIBRARY_CREATE_FILE} (${_tpl})")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_write_fragment")
endfunction()

## @brief Apply recorded component_link edges after all fragments are included.
## @note Walks `BUILDMASTER_COMPONENT_LINK_SOURCES` / `_DESTS` in lockstep.
## @note Dest kinds: meta INTERFACE, registered component (WHOLE vs produced
##       IMPORTED names), existing CMake target, existing archive file, or a
##       library spec that creates an IMPORTED target under the install libdir.
## @note FATAL if source is not a target or dest is BUILDONLY.
function(_buildmaster_apply_links)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_apply_links")
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _lsrcs)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_apply_links")
		return()
	endif()
	set(_i 0)
	foreach(_src IN LISTS _lsrcs)
		list(GET _ldsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")

		if(NOT TARGET "${_src}")
			buildmaster_message(COMPONENT FATAL
				"component_link: source '${_src}' is not a target (missing create_*_component?)")
		endif()

		_buildmaster_meta_is("${_dst}" _dst_meta)
		if(_dst_meta)
			if(TARGET "${_dst}")
				target_link_libraries(${_src} INTERFACE ${_dst})
			endif()
			continue()
		endif()

		_buildmaster_component_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			_buildmaster_component_is_buildonly("${_dst}" _dst_bo)
			if(_dst_bo)
				buildmaster_message(COMPONENT FATAL
					"component_link: cannot link to BUILDONLY component '${_dst}' (order only via component_dependency between BUILDONLY phases, or component_repack to publish)")
			endif()
			# WHOLE dest: INTERFACE already carries whole-archive items; do not
			# also link plain IMPORTED names (would drop whole or double-link).
			get_property(_dst_whole GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_WHOLE)
			if(_dst_whole)
				if(TARGET "${_dst}")
					target_link_libraries(${_src} INTERFACE ${_dst})
				endif()
			else()
				get_property(_names GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_NAMES)
				foreach(_lib IN LISTS _names)
					if(TARGET "${_lib}")
						target_link_libraries(${_src} INTERFACE ${_lib})
					endif()
				endforeach()
				if(TARGET "${_dst}")
					target_link_libraries(${_src} INTERFACE ${_dst})
				endif()
			endif()
			continue()
		endif()

		if(TARGET "${_dst}")
			target_link_libraries(${_src} INTERFACE ${_dst})
			continue()
		endif()

		if(EXISTS "${_dst}" AND NOT IS_DIRECTORY "${_dst}")
			target_link_libraries(${_src} INTERFACE "${_dst}")
			continue()
		endif()

		get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_MODE)
		if(_mode STREQUAL "" OR _mode STREQUAL "headers")
			set(_mode "static")
		endif()
		set(_n "")
		set(_f "")
		set(_d "")
		buildmaster_parse_subcomponent("${_dst}" _t _n0 _s)
		buildmaster_append_library_spec(
			"${_mode}" "${_dst}" "${BUILDMASTER_INSTALL_LIBDIR}" _n _f _d)
		list(GET _n 0 _tn)
		list(GET _f 0 _tf)
		if(NOT TARGET "${_tn}")
			if(_mode STREQUAL "shared")
				add_library(${_tn} SHARED IMPORTED GLOBAL)
			else()
				add_library(${_tn} STATIC IMPORTED GLOBAL)
			endif()
			set_target_properties(${_tn} PROPERTIES
				IMPORTED_LOCATION "${_tf}"
				IMPORTED_LOCATION_DEBUG "${_tf}"
				IMPORTED_LOCATION_RELEASE "${_tf}"
				IMPORTED_LOCATION_MINSIZEREL "${_tf}"
				IMPORTED_LOCATION_RELWITHDEBINFO "${_tf}"
			)
		endif()
		target_link_libraries(${_src} INTERFACE ${_tn})
	endforeach()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_apply_links")
endfunction()

## @brief Deferred materialize: metas, toolchain inherit, components, repacks,
##        links, orphan warn.
## @note Idempotent. Scheduled by `_buildmaster_component_defer_arm`; not public.
##       Harness may call this before configure-time contract checks.
##       Metas are created first so component_link/dependency can resolve them;
##       their INTERFACE is wired after real components exist.
## @note Order: materialize metas → propagate meta TOOLCHAIN onto members →
##       per-id cmake/meson materialize → repacks → meta wire → apply links →
##       orphan warning.
function(_buildmaster_finalize_components)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_finalize_components")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_finalize_components")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED TRUE)

	_buildmaster_materialize_metas()
	_buildmaster_propagate_meta_toolchains()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		foreach(_id IN LISTS _ids)
			get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
			if(_sys STREQUAL "cmake")
				_buildmaster_materialize_cmake("${_id}")
			elseif(_sys STREQUAL "meson")
				_buildmaster_materialize_meson("${_id}")
			else()
				buildmaster_message(COMPONENT FATAL
					"finalize: unknown system '${_sys}' for '${_id}'")
			endif()
		endforeach()
	endif()

	_buildmaster_materialize_repacks()
	_buildmaster_meta_wire()
	_buildmaster_apply_links()
	_buildmaster_warn_orphans()
	buildmaster_message(COMPONENT DEBUG "Component graph finalized")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_finalize_components")
endfunction()
