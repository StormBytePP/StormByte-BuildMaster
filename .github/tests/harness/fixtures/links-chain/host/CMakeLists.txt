cmake_minimum_required(VERSION 3.20)
project(links_host LANGUAGES C)
include(GNUInstallDirs)
add_library(linkshost STATIC host.c)
target_include_directories(linkshost PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
install(TARGETS linkshost
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES links_host.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
