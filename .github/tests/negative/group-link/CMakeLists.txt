cmake_minimum_required(VERSION 3.20)
project(neg_group_link LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")

buildmaster_group(g "outline")
buildmaster_link(does-not-matter g)