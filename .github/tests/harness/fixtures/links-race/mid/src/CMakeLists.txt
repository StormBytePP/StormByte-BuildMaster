cmake_minimum_required(VERSION 3.28)
project(RaceMid-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_library(RaceMid SHARED mid.c)
target_include_directories(RaceMid PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(RaceMid PUBLIC RaceBase)
if(NOT "${BUILDMASTER_INSTALL_LIBDIR}" STREQUAL "")
	set_target_properties(RaceMid PROPERTIES
		BUILD_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
		INSTALL_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
	)
endif()
if(NOT WIN32 AND NOT APPLE)
	target_link_options(RaceMid PRIVATE "LINKER:--no-allow-shlib-undefined")
elseif(APPLE)
	target_link_options(RaceMid PRIVATE "LINKER:-undefined,error")
endif()
install(TARGETS RaceMid
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES race_mid.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
