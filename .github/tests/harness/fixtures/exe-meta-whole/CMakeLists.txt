buildmaster_component(
    wh-lib
    "Harness WHOLE+exe static"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    ""
    static
    "whlib"
    ""
)
buildmaster_component(
    wh-exe
    "Harness WHOLE+exe executable"
    "${CMAKE_CURRENT_SOURCE_DIR}/exe"
    ""
    executable
    "whexe"
    ""
)
buildmaster_meta(wh-meta "Harness WHOLE+exe meta" "WHOLE")
buildmaster_meta_add(wh-meta wh-lib wh-exe)

add_library(wh-host SHARED host.c)
target_link_libraries(wh-host PRIVATE wh-meta)
add_dependencies(wh-host wh-meta_install)

add_custom_target(exe-meta-whole_check
    COMMAND ${CMAKE_COMMAND}
        "-DBUILDMASTER_LINKS_DIR=${BUILDMASTER_LINKS_DIR}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check_link.cmake"
    COMMENT "[BuildMaster/Core     ]: WHOLE meta must not link the exe"
    VERBATIM
)
add_dependencies(exe-meta-whole_check wh-exe_install wh-lib_install wh-meta_install)
