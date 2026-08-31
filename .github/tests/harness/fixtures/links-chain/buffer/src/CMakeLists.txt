cmake_minimum_required(VERSION 3.28)
project(StormByte-Buffer-src C)

include(GNUInstallDirs)

add_library(StormByte-Buffer buffer.c)
target_include_directories(StormByte-Buffer PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(StormByte-Buffer PUBLIC StormByte-Logger)
install(TARGETS StormByte-Buffer ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES stormbyte_buffer.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
