cmake_minimum_required(VERSION 3.28)
project(StormByte-Base-src C)

include(GNUInstallDirs)

add_library(StormByte-Base base.c)
target_include_directories(StormByte-Base PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
install(TARGETS StormByte-Base ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES stormbyte_base.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
