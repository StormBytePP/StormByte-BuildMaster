cmake_minimum_required(VERSION 3.20)
project(grpspeex C)

include(GNUInstallDirs)

add_library(grpspeex STATIC speex.c)
target_include_directories(grpspeex PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS grpspeex
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES grpspeex.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
