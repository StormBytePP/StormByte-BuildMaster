cmake_minimum_required(VERSION 3.20)
project(neg_exe_pc LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/empty.c" "int main(void){return 0;}\n")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/CMakeLists_nested.txt" "cmake_minimum_required(VERSION 3.20)\nproject(x C)\nadd_executable(x empty.c)\n")
# srcdir only needs to exist; FATAL is at create (PC + executable)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/CMakeLists.txt" "cmake_minimum_required(VERSION 3.20)\nproject(negexepc C)\nadd_executable(negexepc empty.c)\n")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/empty.c" "int main(void){return 0;}\n")
buildmaster_component(
    neg-exepc
    "neg exe + PC"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    executable
    "negexepc"
    "PC={VERSION=1.0}"
)
