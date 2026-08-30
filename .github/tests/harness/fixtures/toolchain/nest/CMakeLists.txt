cmake_minimum_required(VERSION 3.20)
project(bm_tc_nest LANGUAGES C)

include(GNUInstallDirs)

if(NOT BUILDMASTER_ROOT)
	message(FATAL_ERROR "bm_tc_nest: BUILDMASTER_ROOT is required")
endif()
if(NOT HARNESS_EXPECT_FAMILY)
	message(FATAL_ERROR "bm_tc_nest: HARNESS_EXPECT_FAMILY is required")
endif()
if(NOT HARNESS_TOOLCHAIN)
	message(FATAL_ERROR "bm_tc_nest: HARNESS_TOOLCHAIN is required")
endif()

add_subdirectory(
	"${BUILDMASTER_ROOT}"
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster"
)
include("${BUILDMASTER_ROOT}/helpers.cmake")

_bm_path_builddir(_mid_cmake_build "mid-cmake")
_bm_backend_cmake_create(
	mid-cmake
	"Harness TOOLCHAIN mid-cmake"
	"${CMAKE_CURRENT_SOURCE_DIR}/../mid-cmake"
	"${_mid_cmake_build}"
	"-DBUILDMASTER_ROOT=${BUILDMASTER_ROOT};-DHARNESS_EXPECT_FAMILY=${HARNESS_EXPECT_FAMILY}"
	static
	"toolchain/tcmidcmake"
	"TOOLCHAIN=${HARNESS_TOOLCHAIN}"
)

_bm_path_builddir(_mid_meson_build "mid-meson")
_bm_backend_meson_create(
	mid-meson
	"Harness TOOLCHAIN mid-meson"
	"${CMAKE_CURRENT_SOURCE_DIR}/../mid-meson"
	"${_mid_meson_build}"
	"-Dexpect_family=${HARNESS_EXPECT_FAMILY}"
	static
	"toolchain/tcmidmeson;toolchain/tcleafmeson"
	"TOOLCHAIN=${HARNESS_TOOLCHAIN}"
)
_bm_materialize_finalize()

add_library(tclib STATIC tc_nest.c)
target_include_directories(tclib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(tclib PUBLIC mid-cmake mid-meson)

install(TARGETS tclib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/toolchain
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/toolchain
)
install(FILES tc_nest.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/toolchain)
