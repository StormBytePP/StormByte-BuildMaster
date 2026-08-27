cmake_minimum_required(VERSION 3.20)
project(bm_tc_leaf_cmake LANGUAGES C)

include(GNUInstallDirs)
include("${CMAKE_CURRENT_SOURCE_DIR}/../expect_family.cmake")

if(NOT HARNESS_EXPECT_FAMILY)
	message(FATAL_ERROR "bm_tc_leaf_cmake: HARNESS_EXPECT_FAMILY is required")
endif()

add_library(tcleafcmake STATIC tc_leaf_cmake.c)
target_include_directories(tcleafcmake PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
harness_apply_expect_family(tcleafcmake)

install(TARGETS tcleafcmake
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/toolchain
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/toolchain
)
install(FILES tc_leaf_cmake.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/toolchain)
