# =============================================================================
# helpers.cmake — include stub only (public entry)
# =============================================================================

if(DEFINED BUILDMASTER_ROOT AND NOT "${BUILDMASTER_ROOT}" STREQUAL ""
		AND NOT CMAKE_CURRENT_LIST_DIR STREQUAL BUILDMASTER_ROOT
		AND EXISTS "${BUILDMASTER_ROOT}/helpers.cmake")
	include("${BUILDMASTER_ROOT}/helpers.cmake")
	return()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/paths.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/library_hints.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/lists.cmake")

# Toolchain first so create_* stages can validate/resolve profiles
include("${BUILDMASTER_SRCDIR}/toolchain/helpers.cmake")

include("${BUILDMASTER_SRCDIR}/env/helpers.cmake")
include("${BUILDMASTER_SRCDIR}/tools/cmake/helpers.cmake")
include("${BUILDMASTER_SRCDIR}/tools/file/helpers.cmake")
include("${BUILDMASTER_SRCDIR}/tools/git/helpers.cmake")
include("${BUILDMASTER_SRCDIR}/tools/meson/helpers.cmake")
include("${BUILDMASTER_SRCDIR}/tools/archive/helpers.cmake")
# Component helpers after tools so cmake/meson stages exist
include("${BUILDMASTER_SRCDIR}/component/helpers.cmake")
