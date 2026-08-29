cmake_minimum_required(VERSION 3.20)
project(bm_rec_meson_mid LANGUAGES C)

include(GNUInstallDirs)

if(NOT BUILDMASTER_ROOT)
	message(FATAL_ERROR "bm_rec_meson_mid: BUILDMASTER_ROOT is required")
endif()

add_subdirectory(
	"${BUILDMASTER_ROOT}"
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster"
)
include("${BUILDMASTER_ROOT}/helpers.cmake")

_bm_path_builddir(_leaf_build "mleaf")
_bm_backend_meson_create(
	mleaf
	"Recursive meson leaf"
	"${CMAKE_CURRENT_SOURCE_DIR}/../leaf"
	"${_leaf_build}"
	""
	static
	"recursive/meson/leaflib"
)
_bm_graph_finalize()

add_library(midlib STATIC mid.c)
target_include_directories(midlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(midlib PUBLIC mleaf)

install(TARGETS midlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/meson
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/meson
)
install(FILES mid.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/recursive/meson)