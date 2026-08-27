cmake_minimum_required(VERSION 3.20)
project(HarnessWholeLib C)

include(GNUInstallDirs)

if(NOT DEFINED HARNESS_WLIB_OUTPUT_NAME)
	set(HARNESS_WLIB_OUTPUT_NAME "wlib")
endif()

add_library(wlib STATIC
	wlib_query.c
	wlib_ctor.c
)
set_target_properties(wlib PROPERTIES OUTPUT_NAME "${HARNESS_WLIB_OUTPUT_NAME}")
target_include_directories(wlib PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

install(TARGETS wlib ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES wlib.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})