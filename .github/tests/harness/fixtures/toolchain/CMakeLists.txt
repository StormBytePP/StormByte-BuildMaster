if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

set(_bm_tc_other "")
set(_bm_tc_expect "")

if(WIN32)
	if(CMAKE_C_COMPILER MATCHES "clang-cl" OR
		(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND
			CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC"))
		set(_bm_tc_other "msvc")
		set(_bm_tc_expect "msvc")
	elseif(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
		set(_bm_tc_other "clang-cl")
		set(_bm_tc_expect "clang-cl")
	endif()
else()
	if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
		set(_bm_tc_other "clang")
		set(_bm_tc_expect "clang")
	elseif(CMAKE_C_COMPILER_ID STREQUAL "Clang" OR
			CMAKE_C_COMPILER_ID STREQUAL "AppleClang")
		set(_bm_tc_other "gcc")
		set(_bm_tc_expect "gcc")
	endif()
endif()

if(NOT _bm_tc_other)
	buildmaster_message(CORE FATAL
		"Harness toolchain swap: unsupported compiler '${CMAKE_C_COMPILER_ID}' (${CMAKE_C_COMPILER})")
endif()

buildmaster_message(CORE STATUS
	"Harness toolchain swap: ${CMAKE_C_COMPILER_ID} → TOOLCHAIN=${_bm_tc_other}")

ensure_build_dir(NEST_TC_BUILD_DIR "nest-tc")
create_cmake_component(
	nest-tc
	"Harness TOOLCHAIN nest"
	"${CMAKE_CURRENT_SOURCE_DIR}/nest"
	"${NEST_TC_BUILD_DIR}"
	"-DBUILDMASTER_ROOT=${BM_TEST_REPO_ROOT};-DHARNESS_EXPECT_FAMILY=${_bm_tc_expect};-DHARNESS_TOOLCHAIN=${_bm_tc_other}"
	static
	"toolchain/tclib"
)
component_link(nest-tc "toolchain/tcmidcmake")
component_link(nest-tc "toolchain/tcmidmeson")
