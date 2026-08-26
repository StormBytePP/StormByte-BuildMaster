cmake_minimum_required(VERSION 3.20)
project(lib_prereq LANGUAGES C)

include(GNUInstallDirs)

add_library(prereqlib STATIC prereq.c)
target_include_directories(prereqlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS prereqlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES prereq.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})