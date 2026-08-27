cmake_minimum_required(VERSION 3.20)
project(HarnessMetaTcInherit C)

include(GNUInstallDirs)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain/expect_family.cmake")

if(NOT HARNESS_EXPECT_FAMILY)
	message(FATAL_ERROR "mtc-inherit: HARNESS_EXPECT_FAMILY is required")
endif()

add_library(mtcinherit STATIC mtc_inherit.c)
target_include_directories(mtcinherit PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
harness_apply_expect_family(mtcinherit)

install(TARGETS mtcinherit
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/meta-toolchain
)
install(FILES mtc_inherit.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/meta-toolchain)
