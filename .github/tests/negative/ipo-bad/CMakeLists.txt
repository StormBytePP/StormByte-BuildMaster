cmake_minimum_required(VERSION 3.20)
project(neg_ipo_bad LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-ipobad
    "neg IPO=nope"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    static
    "negipobad"
    "IPO=nope"
)
