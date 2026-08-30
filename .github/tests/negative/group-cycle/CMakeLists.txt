cmake_minimum_required(VERSION 3.20)
project(neg_group_cycle LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")

buildmaster_group(g1 "one")
buildmaster_group(g2 "two")
buildmaster_group_add(g1 g2)
buildmaster_group_add(g2 g1)
