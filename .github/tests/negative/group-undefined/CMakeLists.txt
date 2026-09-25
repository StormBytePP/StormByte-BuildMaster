cmake_minimum_required(VERSION 3.20)
project(neg_group_undefined LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")

# Named, never created. FATAL is at finalize, not at this call.
buildmaster_group_add(never-made ghost-member)
