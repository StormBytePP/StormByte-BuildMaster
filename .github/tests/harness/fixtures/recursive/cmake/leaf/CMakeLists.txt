cmake_minimum_required(VERSION 3.20)
project(bm_rec_cmake_leaf LANGUAGES C)

include(GNUInstallDirs)

add_library(leaflib STATIC leaf.c)
target_include_directories(leaflib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS leaflib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/cmake
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/cmake
)
install(FILES leaf.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/recursive/cmake)