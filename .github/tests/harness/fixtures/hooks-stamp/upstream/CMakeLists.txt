cmake_minimum_required(VERSION 3.20)
project(hooks_stamp C)

include(GNUInstallDirs)

if(NOT DEFINED HOOK_STAMP_INCLUDE OR HOOK_STAMP_INCLUDE STREQUAL "")
	message(FATAL_ERROR "hooks-stamp: HOOK_STAMP_INCLUDE not passed")
endif()

if(NOT EXISTS "${HOOK_STAMP_INCLUDE}/hook_configure.stamp")
	message(FATAL_ERROR
		"hooks-stamp: component hook did not write hook_configure.stamp")
endif()

add_library(hooks-stamp STATIC hooks_stamp.c)
target_include_directories(hooks-stamp PUBLIC
	${CMAKE_CURRENT_SOURCE_DIR}
	${HOOK_STAMP_INCLUDE}
)
install(TARGETS hooks-stamp ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES "${HOOK_STAMP_INCLUDE}/hook_generated.h"
	DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
	OPTIONAL
)
