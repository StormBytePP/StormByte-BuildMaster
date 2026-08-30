# =============================================================================
# component/graph.cmake — registry and declarative graph
# =============================================================================
# Children: create, edges, resolve. Finalize lives in materialize.cmake.

include("${CMAKE_CURRENT_LIST_DIR}/graph/helpers.cmake")

## @brief Schedule deferred component materialization once per configure.
## @note Uses cmake_language(DEFER) on CMAKE_SOURCE_DIR so all create_* and
##       buildmaster_depend/link/repack calls in the tree are seen first.
##       Requires CMake >= 3.19.
function(_bm_graph_defer_arm)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_defer_arm")
	get_property(_armed GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED)
	if(_armed)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_defer_arm")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED TRUE)
	cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
		CALL _bm_materialize_finalize)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_defer_arm")
endfunction()
