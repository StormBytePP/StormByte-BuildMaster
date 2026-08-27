cmake_minimum_required(VERSION 3.20)
project(HarnessRepackA C)

add_library(alib STATIC alib.c)
set_target_properties(alib PROPERTIES OUTPUT_NAME "alib-static")
target_include_directories(alib PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

add_library(aextra STATIC aextra.c)
set_target_properties(aextra PROPERTIES OUTPUT_NAME "aextra-static")
target_include_directories(aextra PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")