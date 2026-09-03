buildmaster_component(
    em-lib
    "Harness exe-in-meta lib"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    ""
    static
    "emlib"
    ""
)
buildmaster_component(
    em-exe
    "Harness exe-in-meta executable"
    "${CMAKE_CURRENT_SOURCE_DIR}/exe"
    ""
    executable
    "emexe"
    ""
)
buildmaster_meta(em-meta "Harness exe-in-meta")
buildmaster_meta_add(em-meta em-lib em-exe)

add_custom_target(em-meta-nolib_check
    COMMAND ${CMAKE_COMMAND}
        "-DBUILDMASTER_LINKS_DIR=${BUILDMASTER_LINKS_DIR}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check_links.cmake"
    COMMENT "[BuildMaster/Core     ]: exe-in-meta must not export LIBNAMES"
    VERBATIM
)
add_dependencies(em-meta-nolib_check em-exe_install em-lib_install em-meta_install)
