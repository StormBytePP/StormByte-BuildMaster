# =============================================================================
# tools/cmake/helpers.cmake — include stub only
# =============================================================================
# install_rules BEFORE stages so `_bm_install_rules_write` exists when
# `_bm_tools_cmake_stages` emits the install wrapper.

include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../component/install_rules/helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/stages.cmake")
