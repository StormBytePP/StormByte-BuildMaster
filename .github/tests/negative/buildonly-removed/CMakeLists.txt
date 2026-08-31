cmake_minimum_required(VERSION 3.20)
project(neg_buildonly_removed LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-bo
    "neg BUILDONLY removed"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    ""
    static
    "negbo"
    "BUILDONLY"
)
