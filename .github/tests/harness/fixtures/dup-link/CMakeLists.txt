_bm_comp_cmake_create(
    dup-a
    "Harness dup A"
    "${CMAKE_CURRENT_SOURCE_DIR}/a"
    "${CMAKE_CURRENT_BINARY_DIR}/dup-a"
    ""
    static
    "dupalib"
)
_bm_comp_cmake_create(
    dup-b
    "Harness dup B"
    "${CMAKE_CURRENT_SOURCE_DIR}/b"
    "${CMAKE_CURRENT_BINARY_DIR}/dup-b"
    ""
    static
    "dupblib"
)

buildmaster_link(dup-a dup-b)
buildmaster_link(dup-a dup-b)
buildmaster_depend(dup-a dup-b)
