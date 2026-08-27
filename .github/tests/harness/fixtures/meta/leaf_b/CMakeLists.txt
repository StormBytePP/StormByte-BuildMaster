cmake_minimum_required(VERSION 3.20)
project(HarnessMetaLeafB C)

include(GNUInstallDirs)

add_library(metaleafb STATIC leaf_b.c)
target_include_directories(metaleafb PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS metaleafb ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES leaf_b.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})