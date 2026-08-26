cmake_minimum_required(VERSION 3.20)
project(lib_first LANGUAGES C)

include(GNUInstallDirs)

add_library(firstlib STATIC first.c)
target_include_directories(firstlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS firstlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES first.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})