cmake_minimum_required(VERSION 3.28)
project(SharedBuffer-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "buffer src: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../logger"
	"${CMAKE_CURRENT_BINARY_DIR}/logger")

add_library(SharedBuffer SHARED buffer.c)
target_include_directories(SharedBuffer PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(SharedBuffer PUBLIC SharedLogger)
install(TARGETS SharedBuffer
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES shared_buffer.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
