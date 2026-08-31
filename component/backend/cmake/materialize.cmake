# =============================================================================
# component/backend/cmake/materialize.cmake — emit CMake stages + fragment
# =============================================================================

## @brief Emit CMake stages and include the component fragment (internal).
## @param[in] _component Registered component identifier.
## @note Called only from `_bm_materialize_finalize`. Uses
##       `_bm_tools_cmake_stages` and
##       `_bm_materialize_collect_outputs` / `_bm_materialize_write_fragment`.
## @note Eager components print `Configuring …` from the generated
##       configure script. Deferred components print
##       `Setting up <title> for build-time configure` here.
## @note Defer is `_bm_graph_has_deferred_configure`: only registered
##       dests in this process. Link-to-nested-only dests stay eager so
##       `links/<dest>.cmake` exists before flatten/apply_links.
## @note Indent is `BUILDMASTER_COMPONENT_<id>_INDENT` read *after*
##       collect_outputs.
## @note Per-id hooks run after the fragment include (alias order).
function(_bm_backend_cmake_materialize _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_backend_cmake_materialize")
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
	get_property(_toolchain GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_TOOLCHAIN)

	_bm_materialize_collect_outputs("${_component}")

	get_property(_indent_level GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_INDENT)
	if(NOT _indent_level MATCHES "^[0-9]+$")
		set(_indent_level 0)
	endif()

	_bm_graph_has_deferred_configure("${_component}" _deferred)
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

	_bm_tools_cmake_stages(
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

	_bm_materialize_write_fragment("${_component}" "${_deferred}")
	_bm_hook_run_component("${_component}")
	_bm_log_message(COMPONENT DEBUG "Materialized cmake component ${_component} deferred=${_deferred}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_backend_cmake_materialize")
endfunction()
