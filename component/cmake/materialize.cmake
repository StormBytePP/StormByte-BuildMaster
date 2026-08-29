# =============================================================================
# component/cmake/materialize.cmake — emit CMake stages + fragment
# =============================================================================

## @brief Emit CMake stages and include the component fragment (internal).
## @param[in] _component Registered component identifier.
## @note Called only from `_buildmaster_finalize_components`. Uses
##       `create_cmake_stages` (not part of the public API) and shared
##       collect/write helpers from `component/materialize.cmake`.
## @note Eager components print `Configuring …` from the generated
##       configure script (parent include). Deferred components
##       (`component_dependency` sources) print
##       `Setting up <title> for build-time configure` here so parent
##       configure is not silent about them; the real nested configure
##       still runs under `<id>_configure` at build time.
## @note Per-id hooks run after the fragment include (alias order).
function(_buildmaster_materialize_cmake _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_materialize_cmake")
	get_property(_component_title GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_TITLE)
	get_property(_srcdir GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_SRCDIR)
	get_property(_builddir GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_BUILDDIR)
	get_property(_options GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_OPTIONS)
	get_property(_library_mode GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_MODE)

	_buildmaster_component_collect_outputs("${_component}")
	_buildmaster_component_has_deferred_configure("${_component}" _deferred)
	if(_deferred)
		set(_via_target "1")
		set(_tc_suffix "")
		if(NOT _toolchain STREQUAL "")
			set(_tc_suffix " (with toolchain ${_toolchain})")
		endif()
		_bm_log_message(CMAKE STATUS
			"Setting up ${_component_title} for build-time configure${_tc_suffix}"
			"${_indent_level}")
	else()
		set(_via_target "0")
	endif()

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

	_buildmaster_component_write_fragment("${_component}" "${_deferred}")
	_buildmaster_run_component_materialize_hooks("${_component}")
	_bm_log_message(COMPONENT DEBUG "Materialized cmake component ${_component} deferred=${_deferred}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_materialize_cmake")
endfunction()
