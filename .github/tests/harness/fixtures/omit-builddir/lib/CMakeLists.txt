cmake_minimum_required(VERSION 3.20)
project(lib_omit LANGUAGES C)

include(GNUInstallDirs)

add_library(omitlib STATIC omit.c)
target_include_directories(omitlib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS omitlib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES omit.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
