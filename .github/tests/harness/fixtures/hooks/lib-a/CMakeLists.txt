cmake_minimum_required(VERSION 3.20)
project(lib_hooka LANGUAGES C)

include(GNUInstallDirs)

add_library(hookalib STATIC hooka.c)
target_include_directories(hookalib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS hookalib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES hooka.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
