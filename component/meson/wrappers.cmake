# =============================================================================
# component/meson/wrappers.cmake — public Meson component factories
# =============================================================================

## @brief Register a Meson-backed component (INTERFACE `<id>` exists on return).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Deprecated in 2.0.x. Omit for 2.1-style:
##            `id title srcdir options mode produced [optstr]`.
##            Legacy: `id title srcdir builddir options mode produced [optstr]`.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Ignored for headers mode.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
## @note Same arity rules and deprecation as create_cmake_component.
##       2.1.x drops the explicit builddir. No public getter yet.
function(create_meson_component _component _component_title _srcdir)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_meson_component")

	set(_builddir "")
	set(_options "")
	set(_library_mode "")
	set(_produced "")
	set(_options_string "")
	set(_legacy FALSE)

	if(ARGC LESS 6 OR ARGC GREATER 8)
		buildmaster_message(COMPONENT FATAL
			"create_meson_component: expected 6–8 arguments (2.1: id title srcdir options mode produced [optstr]; legacy: id title srcdir builddir options mode produced [optstr])")
	endif()

	if(ARGC EQUAL 6)
		set(_options "${ARGV3}")
		set(_library_mode "${ARGV4}")
		set(_produced "${ARGV5}")
	elseif(ARGC EQUAL 8)
		set(_legacy TRUE)
		set(_builddir "${ARGV3}")
		set(_options "${ARGV4}")
		set(_library_mode "${ARGV5}")
		set(_produced "${ARGV6}")
		set(_options_string "${ARGV7}")
	else()
		_buildmaster_is_library_mode("${ARGV4}" _m21)
		_buildmaster_is_library_mode("${ARGV5}" _m20)
		if(_m21 AND NOT _m20)
			set(_options "${ARGV3}")
			set(_library_mode "${ARGV4}")
			set(_produced "${ARGV5}")
			set(_options_string "${ARGV6}")
		else()
			set(_legacy TRUE)
			set(_builddir "${ARGV3}")
			set(_options "${ARGV4}")
			set(_library_mode "${ARGV5}")
			set(_produced "${ARGV6}")
		endif()
	endif()

	if(_legacy)
		buildmaster_message(COMPONENT WARNING
			"create_meson_component('${_component}'): explicit build directory is deprecated and will be removed in BuildMaster 2.1.x (BuildMaster will assign the directory). There is no public getter for that path yet.")
	else()
		_buildmaster_component_builddir(_builddir "${_component}")
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
## @param[in] _builddir Deprecated in 2.0.x. Same 4–6 arity as
##            create_cmake_headers_component.
## @note 5 arguments are always the legacy form. No public builddir getter yet.
function(create_meson_headers_component _component _component_title _srcdir)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_meson_headers_component")

	set(_builddir "")
	set(_options "")
	set(_options_string "")
	set(_legacy FALSE)

	if(ARGC LESS 4 OR ARGC GREATER 6)
		buildmaster_message(COMPONENT FATAL
			"create_meson_headers_component: expected 4–6 arguments (2.1: id title srcdir options [optstr]; legacy: id title srcdir builddir options [optstr])")
	endif()

	if(ARGC EQUAL 4)
		set(_options "${ARGV3}")
	elseif(ARGC EQUAL 6)
		set(_legacy TRUE)
		set(_builddir "${ARGV3}")
		set(_options "${ARGV4}")
		set(_options_string "${ARGV5}")
	else()
		set(_legacy TRUE)
		set(_builddir "${ARGV3}")
		set(_options "${ARGV4}")
	endif()

	if(_legacy)
		buildmaster_message(COMPONENT WARNING
			"create_meson_headers_component('${_component}'): explicit build directory is deprecated and will be removed in BuildMaster 2.1.x (BuildMaster will assign the directory). There is no public getter for that path yet.")
	else()
		_buildmaster_component_builddir(_builddir "${_component}")
	endif()

	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "headers" "meson" ""
		"${_options_string}"
	)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_meson_headers_component")
endfunction()
