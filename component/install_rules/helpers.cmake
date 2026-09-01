# =============================================================================
# component/install_rules/helpers.cmake — include stub only
# =============================================================================
# Post-install oficios shared by the CMake and Meson backends.
# Include this stub from component/helpers.cmake and from
# tools/{cmake,meson}/helpers.cmake BEFORE stages.cmake so
# `_bm_install_rules_write` exists when stages emit wrappers.

include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/write.cmake")
