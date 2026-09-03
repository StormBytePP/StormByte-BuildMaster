_bm_backend_cmake_create(
    exe-rescan
    "Harness exe static rescan"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    ""
    executable
    "bm_rescan_exe"
    "IPO=fat"
)
