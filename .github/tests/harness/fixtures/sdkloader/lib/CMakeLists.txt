cmake_minimum_required(VERSION 3.20)
project(lib_loader LANGUAGES C)

include(GNUInstallDirs)

add_library(loaderlib STATIC loader.c)
target_include_directories(loaderlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS loaderlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES loader.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})