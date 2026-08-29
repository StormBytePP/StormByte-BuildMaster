cmake_minimum_required(VERSION 3.20)
project(lib_latesrc LANGUAGES C)

include(GNUInstallDirs)

add_library(latesrclib STATIC latesrc.c)
target_include_directories(latesrclib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS latesrclib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES latesrc.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
