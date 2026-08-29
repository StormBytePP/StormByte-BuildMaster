cmake_minimum_required(VERSION 3.20)
project(lib_latedst LANGUAGES C)

include(GNUInstallDirs)

add_library(latedstlib STATIC latedst.c)
target_include_directories(latedstlib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS latedstlib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES latedst.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
