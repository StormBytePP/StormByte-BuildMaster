# =============================================================================
# tools/archive/helpers.cmake — include stub
# =============================================================================
# Usable from configure-time helpers and from cmake -P scripts (pass
# BUILDMASTER_SRCDIR and include this file). Implementation lives in
# find_archiver.cmake so helpers.cmake stays an include-only stub.

if(DEFINED BUILDMASTER_SRCDIR AND EXISTS "${BUILDMASTER_SRCDIR}/log.cmake")
	include("${BUILDMASTER_SRCDIR}/log.cmake")
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
	include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
endif()
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/find_archiver.cmake")
