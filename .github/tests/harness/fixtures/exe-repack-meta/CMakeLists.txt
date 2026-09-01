_bm_backend_cmake_create(
    exe-rpleaf
    "REPACK leaf static NOINSTALL"
    "${CMAKE_CURRENT_SOURCE_DIR}/leaf"
    ""
    static
    "exerpackleaf"
    "NOINSTALL"
)
_bm_backend_cmake_create(
    exe-rpexe
    "REPACK ignored executable dest"
    "${CMAKE_CURRENT_SOURCE_DIR}/exe"
    ""
    executable
    "exerpackexe"
)
_bm_backend_cmake_create(
    exe-rppub
    "REPACK publisher"
    "${CMAKE_CURRENT_SOURCE_DIR}/pub"
    ""
    static
    "exerpackpub"
    "REPACK"
)
buildmaster_depend(exe-rppub exe-rpleaf)
buildmaster_depend(exe-rppub exe-rpexe)
