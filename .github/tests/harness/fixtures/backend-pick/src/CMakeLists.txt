cmake_minimum_required(VERSION 3.20)
project(lib_bepick LANGUAGES C)
include(GNUInstallDirs)
add_library(bepick STATIC bepick.c)
target_include_directories(bepick PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
install(TARGETS bepick
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES bepick.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
