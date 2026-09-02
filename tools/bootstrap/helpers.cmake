# =============================================================================
# tools/bootstrap/helpers.cmake — include stub only
# =============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/ninja/helpers.cmake")
