cmake_minimum_required(VERSION 3.20)
project(grporphan C)

include(GNUInstallDirs)

add_library(grporphan STATIC orphan.c)
target_include_directories(grporphan PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS grporphan
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES grporphan.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
