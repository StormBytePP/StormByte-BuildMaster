# =============================================================================
# component/materialize/none.cmake — headers tree, no nested generate
# =============================================================================

## @brief Materialize a headers tree with no nested generate.
## @param[in] _component Registered id (`SYSTEM` is `none`).
## @note No cmake/meson stages. Creates empty `_configure` / `_build` /
##       `_install` so wait edges resolve. Stamp under BUILDDIR.
##       Does not INTERFACE-include the srcdir (PRIVATE headers: only
##       the direct linker's nested configure receives `-I`).
function(_bm_materialize_none _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_none")
	get_property(_title GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_TITLE)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)
	get_property(_srcdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_SRCDIR)

	if(NOT IS_DIRECTORY "${_srcdir}")
		_bm_log_message(COMPONENT FATAL
			"_bm_materialize_none('${_component}'): srcdir '${_srcdir}' is not a directory")
	endif()

	set(_stamp "${_builddir}/.bm_${_component}_headers.stamp")
	file(MAKE_DIRECTORY "${_builddir}")

	if(NOT TARGET "${_component}_configure")
		add_custom_target(${_component}_configure)
	endif()
	if(NOT TARGET "${_component}_build")
		add_custom_target(${_component}_build)
		add_dependencies(${_component}_build ${_component}_configure)
	endif()
	if(NOT TARGET "${_component}_install")
		add_custom_command(
			OUTPUT "${_stamp}"
			COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
			DEPENDS ${_component}_build
			COMMENT "[BuildMaster/Core     ]: Stamp headers ${_title}"
			VERBATIM)
		add_custom_target(${_component}_install DEPENDS "${_stamp}")
	endif()
	add_dependencies(${_component} ${_component}_install)

	_bm_hook_run_component("${_component}")

	_bm_log_message(COMPONENT DEBUG
		"Materialized headers-none ${_component} stamp=${_stamp}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_none")
endfunction()
