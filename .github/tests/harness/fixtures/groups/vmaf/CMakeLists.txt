cmake_minimum_required(VERSION 3.20)
project(grpvmaf C)

include(GNUInstallDirs)

add_library(grpvmaf STATIC vmaf.c)
target_include_directories(grpvmaf PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS grpvmaf
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES grpvmaf.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
