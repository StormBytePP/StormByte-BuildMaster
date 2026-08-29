cmake_minimum_required(VERSION 3.20)
project(lib_dupa LANGUAGES C)

include(GNUInstallDirs)

add_library(dupalib STATIC dupa.c)
target_include_directories(dupalib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS dupalib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES dupa.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
