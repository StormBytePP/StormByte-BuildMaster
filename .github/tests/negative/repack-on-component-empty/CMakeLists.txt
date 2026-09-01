cmake_minimum_required(VERSION 3.20)
project(neg_repack_empty LANGUAGES C)
add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/src")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/src/empty.c" "int empty_tag(void) { return 1; }\n")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/src/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.20)
project(empty_leaf C)
add_library(negrempty empty.c)
install(TARGETS negrempty ARCHIVE DESTINATION lib)
]=])
buildmaster_component(
    neg-rpempty
    "neg REPACK no members"
    "${CMAKE_CURRENT_BINARY_DIR}/src"
    ""
    static
    "negrempty"
    "REPACK"
)
_bm_materialize_finalize()
