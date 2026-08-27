cmake_minimum_required(VERSION 3.20)
project(HarnessWholeOut C)

include(GNUInstallDirs)

add_library(outlib STATIC outlib.c)
target_include_directories(outlib PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS outlib ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES outlib.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})