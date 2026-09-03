cmake_minimum_required(VERSION 3.20)
project(bm_exe_rescan C)
include(GNUInstallDirs)
add_library(bm_rescan_provider STATIC provider.c)
add_library(bm_rescan_consumer STATIC consumer.c)
add_executable(bm_rescan_exe main.c)
# Provider BEFORE consumer: single-pass bfd drops foo without --start-group.
target_link_libraries(bm_rescan_exe PRIVATE bm_rescan_provider bm_rescan_consumer)
install(TARGETS bm_rescan_exe RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
