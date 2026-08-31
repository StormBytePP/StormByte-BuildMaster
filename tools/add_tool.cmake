# =============================================================================
# tools/add_tool.cmake — add_subdirectory wrapper for tools/<id>
# =============================================================================

## @brief Add and configure one tool under `tools/` (not `bootstrap/*`).
## @param[in] srcdir `cmake`, `meson`, `git`, `file`, or `extra`.
## @param[in] indent_level Optional DEBUG indent. Default 0.
## @note Source is `BUILDMASTER_TOOLS_SRCDIR/<srcdir>`. Binary is
##       `BUILDMASTER_TOOLS_BINDIR/<srcdir>` so demand from a harness
##       fixture (or any dir that is not under tools/) is legal.
macro(_bm_tools_add srcdir)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_add(${srcdir})")
	if(${ARGC} GREATER 1)
		set(_indent_level "${ARGV1}")
	else()
		set(_indent_level 0)
	endif()

	if(NOT BUILDMASTER_TOOLS_SRCDIR OR BUILDMASTER_TOOLS_SRCDIR STREQUAL "")
		_bm_log_message(TOOLS FATAL
			"_bm_tools_add: BUILDMASTER_TOOLS_SRCDIR is empty")
	endif()
	if(NOT BUILDMASTER_TOOLS_BINDIR OR BUILDMASTER_TOOLS_BINDIR STREQUAL "")
		_bm_log_message(TOOLS FATAL
			"_bm_tools_add: BUILDMASTER_TOOLS_BINDIR is empty")
	endif()

	_bm_log_message(TOOLS DEBUG "Setting up ${srcdir}" ${_indent_level})
	add_subdirectory(
		"${BUILDMASTER_TOOLS_SRCDIR}/${srcdir}"
		"${BUILDMASTER_TOOLS_BINDIR}/${srcdir}"
	)
	include("${BUILDMASTER_TOOLS_SRCDIR}/${srcdir}/propagate_vars.cmake")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_TOOLS_ENABLED "${srcdir}")
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_add(${srcdir})")
endmacro()
