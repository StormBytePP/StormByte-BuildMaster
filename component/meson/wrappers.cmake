# =============================================================================
# component/meson/wrappers.cmake — public Meson component factories
# =============================================================================

## @brief Register a Meson-backed component (INTERFACE `<id>` exists on return).
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
## @note Delegates to create_component. Stages and the fragment run at
##       deferred finalize. No fragment path. No include() is required.
function(create_meson_component _component _component_title
								_srcdir _builddir _options _library_mode _produced)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_meson_component")
	if(ARGC GREATER 8)
		buildmaster_message(COMPONENT FATAL
			"create_meson_component: too many arguments (expected at most one options string).")
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_meson_component")
endfunction()

## @brief Register a header-only Meson component (INTERFACE `<id>` on return).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
## @note Delegates to create_component in headers mode. Stages run at
##       deferred finalize. No fragment path. No include() is required.
function(create_meson_headers_component _component _component_title
										_srcdir _builddir _options)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_meson_headers_component")
	if(ARGC GREATER 6)
		buildmaster_message(COMPONENT FATAL
			"create_meson_headers_component: too many arguments (expected at most one options string).")
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_meson_headers_component")
endfunction()
