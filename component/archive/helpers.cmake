# =============================================================================
# component/archive/helpers.cmake — include stub
# =============================================================================
# Strip lives here. Archiver is the toolchain profile, not tools/.

if(DEFINED BUILDMASTER_SRCDIR AND EXISTS "${BUILDMASTER_SRCDIR}/log.cmake")
	include("${BUILDMASTER_SRCDIR}/log.cmake")
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
	include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
endif()
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/strip_msvc_res.cmake")
