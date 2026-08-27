# =============================================================================
# component/cmake/helpers.cmake — CMake wrappers + materialize
# =============================================================================
# Requires create_component and collect/write helpers from
# component/helpers.cmake (loaded first). create_cmake_stages is internal.

include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")

## @brief Register a CMake-backed component (materialized at deferred finalize).
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
function(create_cmake_component _component _component_title
								_srcdir _builddir _options _library_mode _produced)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_cmake_component")
	if(ARGC GREATER 8)
		buildmaster_message(COMPONENT FATAL
			"create_cmake_component: too many arguments (expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 7)
		set(_options_string "${ARGV7}")
	endif()
	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "${_library_mode}" "cmake" "${_produced}"
		"${_options_string}"
	)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_cmake_component")
endfunction()

## @brief Register a header-only CMake component.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
## @note Does not return a fragment path. No include() is required.
function(create_cmake_headers_component _component _component_title
										_srcdir _builddir _options)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_cmake_headers_component")
	if(ARGC GREATER 6)
		buildmaster_message(COMPONENT FATAL
			"create_cmake_headers_component: too many arguments (expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 5)
		set(_options_string "${ARGV5}")
	endif()
	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "headers" "cmake" ""
		"${_options_string}"
	)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_cmake_headers_component")
endfunction()

## @brief Emit CMake stages and include the component fragment (internal).
## @param[in] _component Registered component identifier.
## @note Called only from _buildmaster_finalize_components. Uses
##       create_cmake_stages (not part of the public API) and shared
##       collect/write helpers from component/helpers.cmake.
function(_buildmaster_materialize_cmake _component)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_materialize_cmake")
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
	buildmaster_message(COMPONENT DEBUG "Materialized cmake component ${_component} deferred=${_deferred}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_materialize_cmake")
endfunction()
