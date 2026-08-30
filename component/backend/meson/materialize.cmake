# =============================================================================
# component/backend/meson/materialize.cmake — emit Meson stages + fragment
# =============================================================================

## @brief Emit Meson stages and include the component fragment (internal).
## @param[in] _component Registered component identifier.
## @note Called only from `_bm_materialize_finalize`. Uses
##       `_bm_tools_meson_stages` (not public) and
##       `_bm_materialize_collect_outputs` / `_bm_materialize_write_fragment`.
## @note Eager components print `Configuring …` from the generated
##       setup script (parent include). Deferred components
##       (`buildmaster_depend` sources) print
##       `Setting up <title> for build-time configure` here so parent
##       configure is not silent about them; the real Meson setup
##       still runs under `<id>_configure` at build time.
## @note Indent is `BUILDMASTER_COMPONENT_<id>_INDENT` at *this* call
##       (group plan has already stamped it). Read it AFTER
##       `_bm_materialize_collect_outputs` so a leftover PARENT_SCOPE
##       `_indent_level` cannot overwrite the group depth.
## @note Per-id hooks run after the fragment include (alias order).
function(_bm_backend_meson_materialize _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_backend_meson_materialize")
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
	if("${_indent_level}" STREQUAL "")
		set(_indent_level 0)
	endif()

	_bm_graph_has_deferred_configure("${_component}" _deferred)
	if(_deferred)
		set(_via_target "1")
		set(_tc_suffix "")
		if(NOT _toolchain STREQUAL "")
			set(_tc_suffix " (with toolchain ${_toolchain})")
		endif()
		_bm_log_message(MESON STATUS
			"Setting up ${_component_title} for build-time configure${_tc_suffix}"
			"${_indent_level}")
	else()
		set(_via_target "0")
	endif()

	_bm_tools_meson_stages(
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
	_bm_log_message(COMPONENT DEBUG "Materialized meson component ${_component} deferred=${_deferred}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_backend_meson_materialize")
endfunction()
