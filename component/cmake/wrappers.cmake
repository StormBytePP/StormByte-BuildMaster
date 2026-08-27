# =============================================================================
# component/cmake/wrappers.cmake — public CMake component factories
# =============================================================================

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
