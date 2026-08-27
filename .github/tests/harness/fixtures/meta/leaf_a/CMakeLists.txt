cmake_minimum_required(VERSION 3.20)
project(HarnessMetaLeafA C)

include(GNUInstallDirs)

add_library(metaleafa STATIC leaf_a.c)
target_include_directories(metaleafa PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS metaleafa ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES leaf_a.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})