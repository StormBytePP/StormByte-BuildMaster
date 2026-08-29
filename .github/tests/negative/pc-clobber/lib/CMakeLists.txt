cmake_minimum_required(VERSION 3.20)
project(lib_pcclash LANGUAGES C)

include(GNUInstallDirs)

add_library(pcclashlib STATIC pcclash.c)
target_include_directories(pcclashlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/pcclash.pc"
	"Name: pcclash\nVersion: 0.0.1\nDescription: upstream\n")

install(TARGETS pcclashlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES pcclash.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/pcclash.pc"
	DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)
