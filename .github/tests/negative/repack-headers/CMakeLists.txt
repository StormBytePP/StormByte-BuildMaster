cmake_minimum_required(VERSION 3.20)
project(neg_repack_headers LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-rphdr
    "neg REPACK headers"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    ""
    headers
    ""
    "REPACK"
)
