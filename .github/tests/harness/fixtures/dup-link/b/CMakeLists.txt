cmake_minimum_required(VERSION 3.20)
project(lib_dupb LANGUAGES C)

include(GNUInstallDirs)

add_library(dupblib STATIC dupb.c)
target_include_directories(dupblib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS dupblib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES dupb.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
