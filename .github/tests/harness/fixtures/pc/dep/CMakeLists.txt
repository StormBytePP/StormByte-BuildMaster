cmake_minimum_required(VERSION 3.20)
project(lib_pc_dep LANGUAGES C)

include(GNUInstallDirs)

add_library(pcdeplib STATIC pc_dep.c)
target_include_directories(pcdeplib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS pcdeplib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES pc_dep.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
