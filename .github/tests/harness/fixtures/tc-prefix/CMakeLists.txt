if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

set(_bm_tc_other "")
if(WIN32)
	if(CMAKE_C_COMPILER MATCHES "clang-cl" OR
		(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND
			CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC"))
		set(_bm_tc_other "msvc")
	elseif(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
		set(_bm_tc_other "clang-cl")
	endif()
else()
	if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
		set(_bm_tc_other "clang")
	elseif(CMAKE_C_COMPILER_ID STREQUAL "Clang" OR
			CMAKE_C_COMPILER_ID STREQUAL "AppleClang")
		set(_bm_tc_other "gcc")
	endif()
endif()

if(NOT _bm_tc_other)
	_bm_log_message(CORE FATAL
		"tc-prefix: unsupported compiler '${CMAKE_C_COMPILER_ID}'")
endif()

buildmaster_component(
	tc-prefix
	"Harness TOOLCHAIN dump keeps trunk prefix"
	"${CMAKE_CURRENT_SOURCE_DIR}/tree"
	""
	static
	"tcprefix"
	"TOOLCHAIN=${_bm_tc_other}"
)
