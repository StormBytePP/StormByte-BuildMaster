cmake_minimum_required(VERSION 3.20)
project(bm_rec_cmake_nest LANGUAGES C)

include(GNUInstallDirs)

if(NOT BUILDMASTER_ROOT)
	message(FATAL_ERROR "bm_rec_cmake_nest: BUILDMASTER_ROOT is required")
endif()

add_subdirectory(
	"${BUILDMASTER_ROOT}"
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster"
)
include("${BUILDMASTER_ROOT}/helpers.cmake")

_bm_backend_cmake_create(
	mid
	"Recursive cmake mid"
	"${CMAKE_CURRENT_SOURCE_DIR}/../mid"
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"recursive/cmake/midlib"
)
_bm_materialize_finalize()

add_library(nestlib STATIC nest.c)
target_include_directories(nestlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(nestlib PUBLIC mid)

install(TARGETS nestlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/cmake
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/cmake
)
install(FILES nest.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/recursive/cmake)
