cmake_minimum_required(VERSION 3.20)
project(lib_second LANGUAGES C)

include(GNUInstallDirs)

add_library(secondlib STATIC second.c)
target_include_directories(secondlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS secondlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES second.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})