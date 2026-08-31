cmake_minimum_required(VERSION 3.20)
project(neg_backend_ambiguous LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/meson.build" "project('amb')\n")
buildmaster_component(
    neg-amb
    "neg dual markers no BACKEND"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    ""
    static
    "negamb"
)
