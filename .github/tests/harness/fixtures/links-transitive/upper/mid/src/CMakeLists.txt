cmake_minimum_required(VERSION 3.28)
project(TransMid-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_library(TransMid SHARED mid.c)
target_include_directories(TransMid PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(TransMid PUBLIC TransBase)
if(NOT "${BUILDMASTER_INSTALL_LIBDIR}" STREQUAL "")
	set_target_properties(TransMid PROPERTIES
		BUILD_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
		INSTALL_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
	)
endif()
if(NOT WIN32 AND NOT APPLE)
	target_link_options(TransMid PRIVATE "LINKER:--no-allow-shlib-undefined")
elseif(APPLE)
	target_link_options(TransMid PRIVATE "LINKER:-undefined,error")
endif()
install(TARGETS TransMid
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES trans_mid.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
