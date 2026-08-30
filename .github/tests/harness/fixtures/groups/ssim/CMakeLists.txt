cmake_minimum_required(VERSION 3.20)
project(grpssim C)

include(GNUInstallDirs)

add_library(grpssim STATIC ssim.c)
target_include_directories(grpssim PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS grpssim
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES grpssim.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
