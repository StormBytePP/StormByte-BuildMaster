cmake_minimum_required(VERSION 3.20)
project(bm_tc_mid_cmake LANGUAGES C)

include(GNUInstallDirs)

if(NOT BUILDMASTER_ROOT)
	message(FATAL_ERROR "bm_tc_mid_cmake: BUILDMASTER_ROOT is required")
endif()
if(NOT HARNESS_EXPECT_FAMILY)
	message(FATAL_ERROR "bm_tc_mid_cmake: HARNESS_EXPECT_FAMILY is required")
endif()

add_subdirectory(
	"${BUILDMASTER_ROOT}"
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster"
)
include("${BUILDMASTER_ROOT}/helpers.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/../expect_family.cmake")

ensure_build_dir(_leaf_build "leaf-cmake")
create_cmake_component(
	leaf-cmake
	"Harness TOOLCHAIN leaf-cmake"
	"${CMAKE_CURRENT_SOURCE_DIR}/../leaf-cmake"
	"${_leaf_build}"
	"-DHARNESS_EXPECT_FAMILY=${HARNESS_EXPECT_FAMILY}"
	static
	"toolchain/tcleafcmake"
)
_buildmaster_finalize_components()

add_library(tcmidcmake STATIC tc_mid_cmake.c)
target_include_directories(tcmidcmake PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
harness_apply_expect_family(tcmidcmake)
target_link_libraries(tcmidcmake PUBLIC leaf-cmake)

install(TARGETS tcmidcmake
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/toolchain
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/toolchain
)
install(FILES tc_mid_cmake.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/toolchain)
