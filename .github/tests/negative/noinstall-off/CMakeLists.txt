cmake_minimum_required(VERSION 3.20)
project(neg_noinstall_off LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-nioff
    "neg NOINSTALL=OFF"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    ""
    static
    "negnioff"
    "NOINSTALL=OFF"
)
