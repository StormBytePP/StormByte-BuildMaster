cmake_minimum_required(VERSION 3.28)
project(RaceB-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../mid"
	"${CMAKE_CURRENT_BINARY_DIR}/mid")

add_library(RaceB SHARED race_b.c)
target_include_directories(RaceB PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
if(NOT "${BUILDMASTER_INSTALL_LIBDIR}" STREQUAL "")
	set_target_properties(RaceB PROPERTIES
		BUILD_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
		INSTALL_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
	)
endif()
if(NOT WIN32 AND NOT APPLE)
	target_link_options(RaceB PRIVATE "LINKER:--no-allow-shlib-undefined")
elseif(APPLE)
	target_link_options(RaceB PRIVATE "LINKER:-undefined,error")
endif()

if(NOT COMMAND buildmaster_link)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "race b: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

# Same RaceMid the winner already configured. This skip must still
# link Base and must not compile before that install.
buildmaster_link(RaceB RaceMid)

install(TARGETS RaceB
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES race_b.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
