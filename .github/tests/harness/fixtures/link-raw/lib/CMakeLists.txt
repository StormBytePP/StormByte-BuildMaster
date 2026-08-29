cmake_minimum_required(VERSION 3.20)
project(lib_raw LANGUAGES C)

include(GNUInstallDirs)

add_library(rawlib STATIC raw.c)
target_include_directories(rawlib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS rawlib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES raw.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
