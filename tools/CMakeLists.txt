include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
if(COMMAND _bm_log_level_init)
    _bm_log_level_init()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/init_vars.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/bootstrap/helpers.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/propagate_vars.cmake")
