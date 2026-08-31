cmake_minimum_required(VERSION 3.28)
project(StormByte-Logger-src C)

include(GNUInstallDirs)

add_library(StormByte-Logger logger.c)
target_include_directories(StormByte-Logger PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(StormByte-Logger PUBLIC StormByte-Base)
install(TARGETS StormByte-Logger ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES stormbyte_logger.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
