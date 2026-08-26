# =============================================================================
# component/meson/helpers.cmake — public Meson backend wrappers
# =============================================================================
# Requires create_component from component/helpers.cmake (loaded first).

## @brief Meson component wrapper.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs this component installs
##            (`<name>` or `<subdir>/<name>`).
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_meson_component _library_create_file _component _component_title
								_srcdir _builddir _options _library_mode _produced)
	if(ARGC GREATER 9)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_component: too many arguments "
			"(expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 8)
		set(_options_string "${ARGV8}")
	endif()
	create_component(
		${_library_create_file}
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "${_library_mode}" "meson" "${_produced}" ""
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Dependant Meson component wrapper.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs this component installs.
## @param[in] _dependency Install-target dependency.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_meson_dependant_component _library_create_file _component _component_title
										_srcdir _builddir _options _library_mode
										_produced _dependency)
	if(ARGC GREATER 10)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_dependant_component: too many arguments "
			"(expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 9)
		set(_options_string "${ARGV9}")
	endif()
	create_component(
		${_library_create_file}
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "${_library_mode}" "meson" "${_produced}" "${_dependency}"
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Header-only Meson component.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_meson_headers_component _library_create_file _component _component_title
										_srcdir _builddir _options)
	if(ARGC GREATER 7)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_headers_component: too many arguments "
			"(expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 6)
		set(_options_string "${ARGV6}")
	endif()
	create_component(
		${_library_create_file}
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "headers" "meson" "" ""
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()


## @brief Dependant header-only Meson component.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _dependency Install-target dependency.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
function(create_meson_headers_dependant_component _library_create_file _component
												_component_title _srcdir _builddir
												_options _dependency)
	if(ARGC GREATER 8)
		message(FATAL_ERROR
			"[BuildMaster] create_meson_headers_dependant_component: too many arguments "
			"(expected at most one options string).")
	endif()
	set(_options_string "")
	if(ARGC GREATER 7)
		set(_options_string "${ARGV7}")
	endif()
	create_component(
		${_library_create_file}
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "headers" "meson" "" "${_dependency}"
		"${_options_string}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()
