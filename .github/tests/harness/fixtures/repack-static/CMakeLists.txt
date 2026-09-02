# x265 analogue: two NOINSTALL leaves emit *-static; publisher REPACK
# needs the sealed produced stems (rename runs on *_install, not *_build).

set(_hi "${CMAKE_CURRENT_SOURCE_DIR}/hi")
set(_lo "${CMAKE_CURRENT_SOURCE_DIR}/lo")
set(_pub "${CMAKE_CURRENT_SOURCE_DIR}/pub")

buildmaster_component(
    rs-hi
    "Harness repack-static hi"
    "${_hi}"
    ""
    static
    "rshi"
    "NOINSTALL"
)
buildmaster_component(
    rs-lo
    "Harness repack-static lo"
    "${_lo}"
    ""
    static
    "rslo"
    "NOINSTALL"
)
buildmaster_component(
    rs-pub
    "Harness repack-static publisher"
    "${_pub}"
    ""
    static
    "rspub"
    "REPACK"
)
buildmaster_depend(rs-pub rs-hi)
buildmaster_depend(rs-pub rs-lo)

add_executable(repack_static_link_test
    "${CMAKE_CURRENT_SOURCE_DIR}/repack_static_link_test.c")
target_include_directories(repack_static_link_test PRIVATE "${_hi}" "${_lo}" "${_pub}")
target_link_libraries(repack_static_link_test PRIVATE rs-pub)
add_dependencies(repack_static_link_test rs-pub_install)
