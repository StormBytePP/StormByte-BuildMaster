cmake_minimum_required(VERSION 3.20)
project(consumerdep C)

include(GNUInstallDirs)

add_library(consumerdep STATIC consumerdep.c)

target_include_directories(consumerdep PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS consumerdep ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES consumerdep.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
