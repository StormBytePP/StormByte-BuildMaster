cmake_minimum_required(VERSION 3.20)
project(neg_bad_lf LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
# Unknown platform group must FATAL (not silently ignore).
buildmaster_meta(neg-lf "bad flags" "LINKFLAGS={SOLARIS={-lnosuch}}")
