cmake_minimum_required(VERSION 3.20)
project(neg_exe_repack LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/CMakeLists.txt" "cmake_minimum_required(VERSION 3.20)\nproject(negexerp C)\nadd_executable(negexerp empty.c)\n")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/empty.c" "int main(void){return 0;}\n")
buildmaster_component(
    neg-exerp
    "neg exe + REPACK"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    executable
    "negexerp"
    "REPACK"
)
