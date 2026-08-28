cmake_minimum_required(VERSION 3.12)
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)

project(BuildMasterConsumer LANGUAGES C)

cmake_policy(SET CMP0079 NEW)

add_subdirectory(lib)
add_subdirectory(thirdparty)
