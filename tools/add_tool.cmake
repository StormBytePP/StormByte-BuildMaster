# =============================================================================
# tools/_bm_tools_add.cmake — add_subdirectory wrapper for tools/
# =============================================================================

## @brief Add and configure a build subdirectory for a third-party tool.
## @param[in] srcdir Relative path to the tool's source directory. The path is
##            interpreted relative to `tools/` (this file's parent directory).
## @param[in] indent_level Optional number of tab characters to prepend to the
##            debug line. Defaults to no indentation.
## @note Per-tool "Setting up <name>" is DEBUG. The tools CMakeLists prints
##       the STATUS header `Setting up tools: a, b, …` unconditionally.
##       `BUILDMASTER_VERBOSE` is not consulted here.
## @note Calls
##       `add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/${srcdir}")` and
##       includes `${CMAKE_CURRENT_LIST_DIR}/${srcdir}/propagate_vars.cmake`
##       to import propagation variables defined by the tool. This macro
##       does not validate the presence of `CMakeLists.txt` or
##       `propagate_vars.cmake` in `srcdir`.
## @example
##   _bm_tools_add(myplugin)        # No indentation
##   _bm_tools_add(myplugin 2)      # DEBUG: "Setting up myplugin" indent 2
macro(_bm_tools_add srcdir)
	_bm_log_message(TOOLS LOWLEVEL "Entering _bm_tools_add(${srcdir})")
	if(${ARGC} GREATER 1)
		set(_indent_level "${ARGV1}")
	else()
		set(_indent_level 0)
	endif()

	_bm_log_message(TOOLS DEBUG "Setting up ${srcdir}" ${_indent_level})
	add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/${srcdir}")
	include("${CMAKE_CURRENT_LIST_DIR}/${srcdir}/propagate_vars.cmake")
	_bm_log_message(TOOLS LOWLEVEL "Exiting _bm_tools_add(${srcdir})")
endmacro()
