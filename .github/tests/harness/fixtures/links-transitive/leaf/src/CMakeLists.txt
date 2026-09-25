cmake_minimum_required(VERSION 3.28)
project(TransLeaf-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "trans leaf: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

add_library(TransLeaf SHARED leaf.c)
target_include_directories(TransLeaf PUBLIC
	"${CMAKE_CURRENT_SOURCE_DIR}"
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
if(NOT "${BUILDMASTER_INSTALL_LIBDIR}" STREQUAL "")
	set_target_properties(TransLeaf PROPERTIES
		BUILD_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
		INSTALL_RPATH "${BUILDMASTER_INSTALL_LIBDIR}"
	)
endif()
if(NOT WIN32 AND NOT APPLE)
	target_link_options(TransLeaf PRIVATE "LINKER:--no-allow-shlib-undefined")
elseif(APPLE)
	target_link_options(TransLeaf PRIVATE "LINKER:-undefined,error")
endif()

# Same id as the parent. links/TransUpper.cmake already exists, so this
# skips configure. Do not name TransMid or TransBase: a skip that drops
# their -l fails here (trans_base_only is not in libTransUpper).
buildmaster_component(
	TransUpper
	"Harness transitive upper"
	"${CMAKE_CURRENT_SOURCE_DIR}/../../upper/src"
	""
	shared
	"TransUpper"
)
buildmaster_link(TransLeaf TransUpper)

install(TARGETS TransLeaf
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES trans_leaf.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
