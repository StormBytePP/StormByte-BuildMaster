# =============================================================================
# tools/archive/helpers.cmake — include stub
# =============================================================================
# Usable from configure-time helpers and from cmake -P scripts (pass
# BUILDMASTER_SRCDIR and include this file). Implementation lives next to
# this stub. Including strip_msvc_res.cmake is safe from other -P scripts
# because that file only runs its CLI body when it is the -P entry point.

if(DEFINED BUILDMASTER_SRCDIR AND EXISTS "${BUILDMASTER_SRCDIR}/log.cmake")
	include("${BUILDMASTER_SRCDIR}/log.cmake")
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
	include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
endif()
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/find_archiver.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/strip_msvc_res.cmake")
