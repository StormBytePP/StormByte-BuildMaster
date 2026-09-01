_bm_backend_cmake_create(
    exe-leaf
    "Harness exe leaf lib"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    ""
    static
    "exeleaflib"
)
_bm_backend_cmake_create(
    exe-link
    "Harness exe linking a BM static"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    executable
    "exelink"
)
buildmaster_link(exe-link exe-leaf)
