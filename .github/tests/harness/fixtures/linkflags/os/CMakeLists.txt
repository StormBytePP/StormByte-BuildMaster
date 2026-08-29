cmake_minimum_required(VERSION 3.20)
project(HarnessLinkFlagsOs C)

include(GNUInstallDirs)

add_library(lfos STATIC lfos.c)
target_include_directories(lfos PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS lfos ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES lfos.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
