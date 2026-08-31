cmake_minimum_required(VERSION 3.20)
project(tcprefix C)
include(GNUInstallDirs)
add_library(tcprefix STATIC tcprefix.c)
target_include_directories(tcprefix PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
install(TARGETS tcprefix
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES tcprefix.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
