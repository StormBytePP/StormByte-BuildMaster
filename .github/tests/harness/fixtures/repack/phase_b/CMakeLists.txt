cmake_minimum_required(VERSION 3.20)
project(HarnessRepackB C)

add_library(blib STATIC blib.c)
set_target_properties(blib PROPERTIES OUTPUT_NAME "blib-static")
target_include_directories(blib PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")