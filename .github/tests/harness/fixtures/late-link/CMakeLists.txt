# dest is created AFTER the link. The edge must still defer src configure.

create_cmake_component(
    late-src
    "Harness late-link source"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_BINARY_DIR}/late-src"
    ""
    static
    "latesrclib"
)

component_link(late-src late-dst)

create_cmake_component(
    late-dst
    "Harness late-link dest"
    "${CMAKE_CURRENT_SOURCE_DIR}/dst"
    "${CMAKE_CURRENT_BINARY_DIR}/late-dst"
    ""
    static
    "latedstlib"
)
