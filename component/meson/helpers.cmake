# =============================================================================
# component/meson/helpers.cmake — Meson wrappers + materialize
# =============================================================================
# Requires create_component and collect/write helpers from
# component/helpers.cmake (loaded first). create_meson_stages is internal.

## @brief Register a Meson-backed component (materialized at deferred finalize).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Ignored for headers mode.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
## @note Does not return a fragment path. No include() is required.
function(create_meson_component _component _component_title
								_srcdir _builddir _options _library_mode _produced)
	if(ARGC GREATER 8)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_component: too many arguments "
			"(expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 7)
		set(_options_string "${ARGV7}")
	endif()
	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "${_library_mode}" "meson" "${_produced}"
		"${_options_string}"
	)
endfunction()

## @brief Register a header-only Meson component.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
## @note Does not return a fragment path. No include() is required.
function(create_meson_headers_component _component _component_title
										_srcdir _builddir _options)
	if(ARGC GREATER 6)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_headers_component: too many arguments "
			"(expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 5)
		set(_options_string "${ARGV5}")
	endif()
	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "headers" "meson" ""
		"${_options_string}"
	)
endfunction()

## @brief Emit Meson stages and include the component fragment (internal).
## @param[in] _component Registered component identifier.
## @note Called only from _buildmaster_finalize_components. Uses
##       create_meson_stages (not part of the public API) and shared
##       collect/write helpers from component/helpers.cmake.
function(_buildmaster_materialize_meson _component)
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
	else()
		set(_via_target "0")
	endif()

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

	_buildmaster_component_write_fragment("${_component}" "${_deferred}")
endfunction()
