cmake_minimum_required(VERSION 3.20)
project(HarnessMetaOut C)

include(GNUInstallDirs)

add_library(metaout STATIC metaout.c)
target_include_directories(metaout PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS metaout ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES metaout.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})