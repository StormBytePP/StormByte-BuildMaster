cmake_minimum_required(VERSION 3.20)
project(neg_repack_plus_noinstall LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-rpni
    "neg REPACK+NOINSTALL"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    ""
    static
    "negrpni"
    "REPACK;NOINSTALL"
)
