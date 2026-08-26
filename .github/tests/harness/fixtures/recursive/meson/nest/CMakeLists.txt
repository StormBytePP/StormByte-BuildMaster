cmake_minimum_required(VERSION 3.20)
project(bm_rec_meson_nest LANGUAGES C)

include(GNUInstallDirs)

if(NOT BUILDMASTER_ROOT)
	message(FATAL_ERROR "bm_rec_meson_nest: BUILDMASTER_ROOT is required")
endif()

add_subdirectory(
	"${BUILDMASTER_ROOT}"
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster"
)
include("${BUILDMASTER_ROOT}/helpers.cmake")

ensure_build_dir(_mid_build "mmid")
create_cmake_component(
	mmid
	"Recursive meson mid"
	"${CMAKE_CURRENT_SOURCE_DIR}/../mid"
	"${_mid_build}"
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT}"
	static
	"recursive/meson/midlib"
)
_buildmaster_finalize_components()

add_library(nestlib STATIC nest.c)
target_include_directories(nestlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(nestlib PUBLIC mmid)

install(TARGETS nestlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/meson
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/recursive/meson
)
install(FILES nest.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/recursive/meson)