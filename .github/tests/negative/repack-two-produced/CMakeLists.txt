cmake_minimum_required(VERSION 3.20)
project(neg_repack_two_produced LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-rptwo
    "neg REPACK two produced"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    ""
    static
    "one;two"
    "REPACK"
)
