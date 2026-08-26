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

ensure_build_dir(_leaf_build "mleaf")
create_meson_component(
	mleaf
	"Recursive meson leaf"
	"${CMAKE_CURRENT_SOURCE_DIR}/../leaf"
	"${_leaf_build}"
	""
	static
	"recursive/meson/leaflib"
)
_buildmaster_finalize_components()

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