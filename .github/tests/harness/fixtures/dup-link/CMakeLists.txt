create_cmake_component(
    dup-a
    "Harness dup A"
    "${CMAKE_CURRENT_SOURCE_DIR}/a"
    "${CMAKE_CURRENT_BINARY_DIR}/dup-a"
    ""
    static
    "dupalib"
)
create_cmake_component(
    dup-b
    "Harness dup B"
    "${CMAKE_CURRENT_SOURCE_DIR}/b"
    "${CMAKE_CURRENT_BINARY_DIR}/dup-b"
    ""
    static
    "dupblib"
)

component_link(dup-a dup-b)
component_link(dup-a dup-b)
component_dependency(dup-a dup-b)
