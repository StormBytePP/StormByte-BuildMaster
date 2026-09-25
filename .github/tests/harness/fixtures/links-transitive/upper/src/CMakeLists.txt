cmake_minimum_required(VERSION 3.28)
project(TransUpper-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../mid"
	"${CMAKE_CURRENT_BINARY_DIR}/mid")

add_library(TransUpper SHARED upper.c)
target_include_directories(TransUpper PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(TransUpper PUBLIC TransMid)
if(NOT "${BUILDMASTER_INSTALL_LIBDIR}" STREQUAL "")
	set_target_properties(TransUpper PROPERTIES
		BUILD_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
		INSTALL_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
	)
endif()
if(NOT WIN32 AND NOT APPLE)
	target_link_options(TransUpper PRIVATE "LINKER:--no-allow-shlib-undefined")
elseif(APPLE)
	target_link_options(TransUpper PRIVATE "LINKER:-undefined,error")
endif()
install(TARGETS TransUpper
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES trans_upper.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
