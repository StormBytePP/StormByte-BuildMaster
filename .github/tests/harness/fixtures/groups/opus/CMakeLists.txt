cmake_minimum_required(VERSION 3.20)
project(grpopus C)

include(GNUInstallDirs)

add_library(grpopus STATIC opus.c)
target_include_directories(grpopus PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS grpopus
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES grpopus.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
