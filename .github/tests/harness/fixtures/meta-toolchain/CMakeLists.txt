# Meta TOOLCHAIN inheritance:
#   meta-tc          TOOLCHAIN=<other>
#   mtc-inherit      no TOOLCHAIN → must compile as <other>
#   mtc-pinned       TOOLCHAIN=<host> → must stay <host>
#
# Compile-time #error (same header as fixtures/toolchain) fails the build
# if inherit is dropped or overwrites the pinned child.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

set(_bm_tc_host "")
set(_bm_tc_other "")

if(WIN32)
	if(CMAKE_C_COMPILER MATCHES "clang-cl" OR
		(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND
			CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC"))
		set(_bm_tc_host "clang-cl")
		set(_bm_tc_other "msvc")
	elseif(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
		set(_bm_tc_host "msvc")
		set(_bm_tc_other "clang-cl")
	endif()
else()
	if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
		set(_bm_tc_host "gcc")
		set(_bm_tc_other "clang")
	elseif(CMAKE_C_COMPILER_ID STREQUAL "Clang" OR
			CMAKE_C_COMPILER_ID STREQUAL "AppleClang")
		set(_bm_tc_host "clang")
		set(_bm_tc_other "gcc")
	endif()
endif()

if(NOT _bm_tc_other)
	_bm_log_message(CORE FATAL
		"Harness meta-toolchain: unsupported compiler '${CMAKE_C_COMPILER_ID}' (${CMAKE_C_COMPILER})")
endif()

_bm_log_message(CORE STATUS
	"Harness meta TOOLCHAIN inherit: host=${_bm_tc_host} meta=${_bm_tc_other}")

set(_inh_src "${CMAKE_CURRENT_SOURCE_DIR}/inherit")
set(_pin_src "${CMAKE_CURRENT_SOURCE_DIR}/pinned")
set(_inh_build "${CMAKE_CURRENT_BINARY_DIR}/inherit_build")
set(_pin_build "${CMAKE_CURRENT_BINARY_DIR}/pinned_build")
file(MAKE_DIRECTORY "${_inh_build}" "${_pin_build}")

buildmaster_meta_add(meta-tc mtc-inherit)
buildmaster_meta_add(meta-tc mtc-pinned)

_bm_comp_cmake_create(
	mtc-inherit
	"Harness meta-toolchain inherit leaf"
	"${_inh_src}"
	"${_inh_build}"
	"-DHARNESS_EXPECT_FAMILY=${_bm_tc_other}"
	static
	"meta-toolchain/mtcinherit"
)

_bm_comp_cmake_create(
	mtc-pinned
	"Harness meta-toolchain pinned leaf"
	"${_pin_src}"
	"${_pin_build}"
	"-DHARNESS_EXPECT_FAMILY=${_bm_tc_host}"
	static
	"meta-toolchain/mtcpinned"
	"TOOLCHAIN=${_bm_tc_host}"
)

buildmaster_meta(
	meta-tc
	"Harness meta with TOOLCHAIN"
	"TOOLCHAIN=${_bm_tc_other}"
)
