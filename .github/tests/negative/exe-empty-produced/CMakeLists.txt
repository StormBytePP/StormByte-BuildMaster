cmake_minimum_required(VERSION 3.20)
project(neg_exe_empty LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/CMakeLists.txt" "cmake_minimum_required(VERSION 3.20)\nproject(negexe0 C)\n")
buildmaster_component(
    neg-exe0
    "neg exe empty produced"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    executable
    ""
)
