cmake_minimum_required(VERSION 3.20)
project(lateleaf C)

include(GNUInstallDirs)

add_library(lateleaf STATIC lateleaf.c)
target_include_directories(lateleaf PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS lateleaf
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES lateleaf.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
