cmake_minimum_required(VERSION 3.20)
project(lib_hookb LANGUAGES C)

include(GNUInstallDirs)

add_library(hookblib STATIC hookb.c)
target_include_directories(hookblib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS hookblib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES hookb.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
