if(DEFINED BUILDMASTER_ROOT AND EXISTS "${BUILDMASTER_ROOT}/log.cmake")
	include("${BUILDMASTER_ROOT}/log.cmake")
elseif(DEFINED BM_TEST_REPO_ROOT AND EXISTS "${BM_TEST_REPO_ROOT}/log.cmake")
	include("${BM_TEST_REPO_ROOT}/log.cmake")
endif()
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

## @brief Apply the expected compiler-family compile definition to a target.
## @param[in] _tgt CMake target name (already created with add_library / add_executable).
## @note Reads `HARNESS_EXPECT_FAMILY` (`gcc`, `clang`, `msvc`, `clang-cl`).
##       Defines exactly one of `HARNESS_EXPECT_FAMILY_GCC`,
##       `HARNESS_EXPECT_FAMILY_CLANG`, `HARNESS_EXPECT_FAMILY_MSVC`,
##       `HARNESS_EXPECT_FAMILY_CLANG_CL` as a PRIVATE compile definition.
##       Unknown or empty values are a fatal harness error.
function(harness_apply_expect_family _tgt)
	if(NOT HARNESS_EXPECT_FAMILY)
		_bm_log_message(CORE FATAL "toolchain fixture: HARNESS_EXPECT_FAMILY is required")
	endif()
	string(TOLOWER "${HARNESS_EXPECT_FAMILY}" _f)
	if(_f STREQUAL "clang-cl")
		target_compile_definitions(${_tgt} PRIVATE HARNESS_EXPECT_FAMILY_CLANG_CL=1)
	elseif(_f STREQUAL "msvc")
		target_compile_definitions(${_tgt} PRIVATE HARNESS_EXPECT_FAMILY_MSVC=1)
	elseif(_f STREQUAL "clang")
		target_compile_definitions(${_tgt} PRIVATE HARNESS_EXPECT_FAMILY_CLANG=1)
	elseif(_f STREQUAL "gcc")
		target_compile_definitions(${_tgt} PRIVATE HARNESS_EXPECT_FAMILY_GCC=1)
	else()
		_bm_log_message(CORE FATAL
			"toolchain fixture: unknown HARNESS_EXPECT_FAMILY=${HARNESS_EXPECT_FAMILY}")
	endif()
endfunction()
