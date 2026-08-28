cmake_minimum_required(VERSION 3.20)
project(BuildMasterConsumer LANGUAGES C)

add_subdirectory(thirdparty)

add_executable(consumer_host "${CMAKE_CURRENT_SOURCE_DIR}/host.c")
target_link_libraries(consumer_host PRIVATE consumer-dep)
