buildmaster_toolchain_export(BUILDMASTER_TOOLS_CMAKE_SRCDIR "${BUILDMASTER_TOOLS_CMAKE_SRCDIR}")
buildmaster_toolchain_export(BUILDMASTER_SCRIPTS_CMAKEDIR "${BUILDMASTER_SCRIPTS_CMAKEDIR}")
buildmaster_toolchain_export_raw("set(ENV_CMAKE_COMMAND ${ENV_CMAKE_COMMAND})")
buildmaster_toolchain_export_raw("set(ENV_CMAKE_SILENT_COMMAND ${ENV_CMAKE_SILENT_COMMAND})")
buildmaster_toolchain_export_raw("set(ENV_CMAKE_COMPILE_COMMAND ${ENV_CMAKE_COMPILE_COMMAND})")

# Propagate linker selection from parent (MSVC link.exe, or LLD / lld-link for clang-cl).
# Only write non-empty values so Linux/macOS toolchains stay untouched when unset.
# Paths must be CMake-style (forward slashes) via normalize_cmake_path.
if(DEFINED CMAKE_LINKER_TYPE AND NOT "${CMAKE_LINKER_TYPE}" STREQUAL "")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_LINKER_TYPE \"${CMAKE_LINKER_TYPE}\" CACHE STRING \"BuildMaster linker type\" FORCE)")
endif()

if(DEFINED CMAKE_LINKER AND NOT "${CMAKE_LINKER}" STREQUAL "")
	normalize_cmake_path(_bm_linker "${CMAKE_LINKER}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster linker\" FORCE)")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_C_COMPILER_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster C linker\" FORCE)")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_CXX_COMPILER_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster CXX linker\" FORCE)")
endif()

if(DEFINED CMAKE_C_COMPILER_LINKER AND NOT "${CMAKE_C_COMPILER_LINKER}" STREQUAL ""
		AND (NOT DEFINED CMAKE_LINKER OR "${CMAKE_LINKER}" STREQUAL ""))
	normalize_cmake_path(_bm_c_linker "${CMAKE_C_COMPILER_LINKER}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_C_COMPILER_LINKER \"${_bm_c_linker}\" CACHE FILEPATH \"BuildMaster C linker\" FORCE)")
endif()

if(DEFINED CMAKE_CXX_COMPILER_LINKER AND NOT "${CMAKE_CXX_COMPILER_LINKER}" STREQUAL ""
		AND (NOT DEFINED CMAKE_LINKER OR "${CMAKE_LINKER}" STREQUAL ""))
	normalize_cmake_path(_bm_cxx_linker "${CMAKE_CXX_COMPILER_LINKER}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_CXX_COMPILER_LINKER \"${_bm_cxx_linker}\" CACHE FILEPATH \"BuildMaster CXX linker\" FORCE)")
endif()

if(DEFINED CMAKE_MT AND NOT "${CMAKE_MT}" STREQUAL "" AND NOT "${CMAKE_MT}" STREQUAL "mt")
	normalize_cmake_path(_bm_mt "${CMAKE_MT}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_MT \"${_bm_mt}\" CACHE FILEPATH \"BuildMaster mt\" FORCE)")
elseif(DEFINED CMAKE_MT AND "${CMAKE_MT}" STREQUAL "mt")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_MT \"mt\" CACHE FILEPATH \"BuildMaster mt\" FORCE)")
endif()

if(DEFINED CMAKE_EXE_LINKER_FLAGS AND NOT "${CMAKE_EXE_LINKER_FLAGS}" STREQUAL "")
	string(REPLACE "\"" "\\\"" _bm_elf "${CMAKE_EXE_LINKER_FLAGS}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_EXE_LINKER_FLAGS \"${_bm_elf}\" CACHE STRING \"\" FORCE)")
endif()
if(DEFINED CMAKE_SHARED_LINKER_FLAGS AND NOT "${CMAKE_SHARED_LINKER_FLAGS}" STREQUAL "")
	string(REPLACE "\"" "\\\"" _bm_slf "${CMAKE_SHARED_LINKER_FLAGS}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_SHARED_LINKER_FLAGS \"${_bm_slf}\" CACHE STRING \"\" FORCE)")
endif()
if(DEFINED CMAKE_MODULE_LINKER_FLAGS AND NOT "${CMAKE_MODULE_LINKER_FLAGS}" STREQUAL "")
	string(REPLACE "\"" "\\\"" _bm_mlf "${CMAKE_MODULE_LINKER_FLAGS}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_MODULE_LINKER_FLAGS \"${_bm_mlf}\" CACHE STRING \"\" FORCE)")
endif()

# Archiver / ranlib / nm (llvm-lib for clang-cl LTO static archives)
if(DEFINED CMAKE_AR AND NOT "${CMAKE_AR}" STREQUAL "")
	normalize_cmake_path(_bm_ar "${CMAKE_AR}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster AR\" FORCE)")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_C_COMPILER_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster C AR\" FORCE)")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_CXX_COMPILER_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster CXX AR\" FORCE)")
endif()
if(DEFINED CMAKE_RANLIB AND NOT "${CMAKE_RANLIB}" STREQUAL "")
	normalize_cmake_path(_bm_ranlib "${CMAKE_RANLIB}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"BuildMaster RANLIB\" FORCE)")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_C_COMPILER_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"\" FORCE)")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_CXX_COMPILER_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"\" FORCE)")
endif()
if(DEFINED CMAKE_NM AND NOT "${CMAKE_NM}" STREQUAL "")
	normalize_cmake_path(_bm_nm "${CMAKE_NM}")
	buildmaster_toolchain_export_raw(
		"set(CMAKE_NM \"${_bm_nm}\" CACHE FILEPATH \"BuildMaster NM\" FORCE)")
endif()