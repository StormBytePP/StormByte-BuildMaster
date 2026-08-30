cmake_minimum_required(VERSION 3.20)
project(lib_payload LANGUAGES C)

include(GNUInstallDirs)

add_library(payloadlib STATIC payload.c)
target_include_directories(payloadlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS payloadlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES payload.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
