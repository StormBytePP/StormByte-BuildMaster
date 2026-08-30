# =============================================================================
# component/backend/meson/wrappers.cmake — Meson component factories
# =============================================================================

## @brief Register a Meson-backed component (INTERFACE `<id>` exists on return).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Ignored for headers mode.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See _bm_graph_create for supported keys.
## @note No build-directory argument. `_bm_graph_create` assigns
##       `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>`.
function(_bm_backend_meson_create _component _component_title _srcdir
		_options _library_mode _produced)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_backend_meson_create")
	if(ARGC LESS 6 OR ARGC GREATER 7)
		_bm_log_message(COMPONENT FATAL
			"_bm_backend_meson_create: expected id title srcdir options mode produced [optstr]")
	endif()
	set(_options_string "")
	if(ARGC EQUAL 7)
		set(_options_string "${ARGV6}")
	endif()
	_bm_graph_create(
		"${_component}" "${_component_title}" "${_srcdir}"
		"${_options}" "${_library_mode}" "meson" "${_produced}"
		"${_options_string}"
	)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_backend_meson_create")
endfunction()

## @brief Register a header-only Meson component (INTERFACE `<id>` on return).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] options_string Optional trailing optstr.
function(_bm_backend_meson_create_headers _component _component_title _srcdir
		_options)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_backend_meson_create_headers")
	if(ARGC LESS 4 OR ARGC GREATER 5)
		_bm_log_message(COMPONENT FATAL
			"_bm_backend_meson_create_headers: expected id title srcdir options [optstr]")
	endif()
	set(_options_string "")
	if(ARGC EQUAL 5)
		set(_options_string "${ARGV4}")
	endif()
	_bm_graph_create(
		"${_component}" "${_component_title}" "${_srcdir}"
		"${_options}" "headers" "meson" ""
		"${_options_string}"
	)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_backend_meson_create_headers")
endfunction()
