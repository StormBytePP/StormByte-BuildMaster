cmake_minimum_required(VERSION 3.20)
project(HarnessMetaTcPinned C)

include(GNUInstallDirs)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain/expect_family.cmake")

if(NOT HARNESS_EXPECT_FAMILY)
	message(FATAL_ERROR "mtc-pinned: HARNESS_EXPECT_FAMILY is required")
endif()

add_library(mtcpinned STATIC mtc_pinned.c)
target_include_directories(mtcpinned PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
harness_apply_expect_family(mtcpinned)

install(TARGETS mtcpinned
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/meta-toolchain
)
install(FILES mtc_pinned.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/meta-toolchain)
