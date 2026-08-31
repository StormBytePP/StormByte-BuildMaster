cmake_minimum_required(VERSION 3.20)
project(neg_backend_pick_cmake LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
buildmaster_component(
    neg-pick
    "neg BACKEND=cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    static
    "negpick"
    "BACKEND=cmake"
)
