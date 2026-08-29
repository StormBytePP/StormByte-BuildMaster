cmake_minimum_required(VERSION 3.20)
project(HarnessLinkFlagsUnix C)

include(GNUInstallDirs)

add_library(lfunix STATIC lfunix.c)
target_include_directories(lfunix PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS lfunix ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES lfunix.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
