_bm_tc_export(BUILDMASTER_TOOLS_CMAKE_SRCDIR "${BUILDMASTER_TOOLS_CMAKE_SRCDIR}")
_bm_tc_export(BUILDMASTER_SCRIPTS_CMAKEDIR "${BUILDMASTER_SCRIPTS_CMAKEDIR}")
_bm_tc_export_raw("set(ENV_CMAKE_COMMAND ${ENV_CMAKE_COMMAND})")
_bm_tc_export_raw("set(ENV_CMAKE_SILENT_COMMAND ${ENV_CMAKE_SILENT_COMMAND})")
_bm_tc_export_raw("set(ENV_CMAKE_COMPILE_COMMAND ${ENV_CMAKE_COMPILE_COMMAND})")

# Propagate linker selection from parent (MSVC link.exe, or LLD / lld-link for clang-cl).
# Only write non-empty values so Linux/macOS toolchains stay untouched when unset.
# Paths must be CMake-style (forward slashes) via _bm_path_normalize.
if(DEFINED CMAKE_LINKER_TYPE AND NOT "${CMAKE_LINKER_TYPE}" STREQUAL "")
	_bm_tc_export_raw(
		"set(CMAKE_LINKER_TYPE \"${CMAKE_LINKER_TYPE}\" CACHE STRING \"BuildMaster linker type\" FORCE)")
endif()

if(DEFINED CMAKE_LINKER AND NOT "${CMAKE_LINKER}" STREQUAL "")
	_bm_path_normalize(_bm_linker "${CMAKE_LINKER}")
	_bm_tc_export_raw(
		"set(CMAKE_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster linker\" FORCE)")
	_bm_tc_export_raw(
		"set(CMAKE_C_COMPILER_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster C linker\" FORCE)")
	_bm_tc_export_raw(
		"set(CMAKE_CXX_COMPILER_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster CXX linker\" FORCE)")
endif()

if(DEFINED CMAKE_C_COMPILER_LINKER AND NOT "${CMAKE_C_COMPILER_LINKER}" STREQUAL ""
		AND (NOT DEFINED CMAKE_LINKER OR "${CMAKE_LINKER}" STREQUAL ""))
	_bm_path_normalize(_bm_c_linker "${CMAKE_C_COMPILER_LINKER}")
	_bm_tc_export_raw(
		"set(CMAKE_C_COMPILER_LINKER \"${_bm_c_linker}\" CACHE FILEPATH \"BuildMaster C linker\" FORCE)")
endif()

if(DEFINED CMAKE_CXX_COMPILER_LINKER AND NOT "${CMAKE_CXX_COMPILER_LINKER}" STREQUAL ""
		AND (NOT DEFINED CMAKE_LINKER OR "${CMAKE_LINKER}" STREQUAL ""))
	_bm_path_normalize(_bm_cxx_linker "${CMAKE_CXX_COMPILER_LINKER}")
	_bm_tc_export_raw(
		"set(CMAKE_CXX_COMPILER_LINKER \"${_bm_cxx_linker}\" CACHE FILEPATH \"BuildMaster CXX linker\" FORCE)")
endif()

if(DEFINED CMAKE_MT AND NOT "${CMAKE_MT}" STREQUAL "" AND NOT "${CMAKE_MT}" STREQUAL "mt")
	_bm_path_normalize(_bm_mt "${CMAKE_MT}")
	_bm_tc_export_raw(
		"set(CMAKE_MT \"${_bm_mt}\" CACHE FILEPATH \"BuildMaster mt\" FORCE)")
elseif(DEFINED CMAKE_MT AND "${CMAKE_MT}" STREQUAL "mt")
	_bm_tc_export_raw(
		"set(CMAKE_MT \"mt\" CACHE FILEPATH \"BuildMaster mt\" FORCE)")
endif()

if(DEFINED CMAKE_EXE_LINKER_FLAGS AND NOT "${CMAKE_EXE_LINKER_FLAGS}" STREQUAL "")
	string(REPLACE "\"" "\\\"" _bm_elf "${CMAKE_EXE_LINKER_FLAGS}")
	_bm_tc_export_raw(
		"set(CMAKE_EXE_LINKER_FLAGS \"${_bm_elf}\" CACHE STRING \"\" FORCE)")
endif()
if(DEFINED CMAKE_SHARED_LINKER_FLAGS AND NOT "${CMAKE_SHARED_LINKER_FLAGS}" STREQUAL "")
	string(REPLACE "\"" "\\\"" _bm_slf "${CMAKE_SHARED_LINKER_FLAGS}")
	_bm_tc_export_raw(
		"set(CMAKE_SHARED_LINKER_FLAGS \"${_bm_slf}\" CACHE STRING \"\" FORCE)")
endif()
if(DEFINED CMAKE_MODULE_LINKER_FLAGS AND NOT "${CMAKE_MODULE_LINKER_FLAGS}" STREQUAL "")
	string(REPLACE "\"" "\\\"" _bm_mlf "${CMAKE_MODULE_LINKER_FLAGS}")
	_bm_tc_export_raw(
		"set(CMAKE_MODULE_LINKER_FLAGS \"${_bm_mlf}\" CACHE STRING \"\" FORCE)")
endif()

# Archiver / ranlib / nm (llvm-lib for clang-cl LTO static archives)
if(DEFINED CMAKE_AR AND NOT "${CMAKE_AR}" STREQUAL "")
	_bm_path_normalize(_bm_ar "${CMAKE_AR}")
	_bm_tc_export_raw(
		"set(CMAKE_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster AR\" FORCE)")
	_bm_tc_export_raw(
		"set(CMAKE_C_COMPILER_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster C AR\" FORCE)")
	_bm_tc_export_raw(
		"set(CMAKE_CXX_COMPILER_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster CXX AR\" FORCE)")
endif()
if(DEFINED CMAKE_RANLIB AND NOT "${CMAKE_RANLIB}" STREQUAL "")
	_bm_path_normalize(_bm_ranlib "${CMAKE_RANLIB}")
	_bm_tc_export_raw(
		"set(CMAKE_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"BuildMaster RANLIB\" FORCE)")
	_bm_tc_export_raw(
		"set(CMAKE_C_COMPILER_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"\" FORCE)")
	_bm_tc_export_raw(
		"set(CMAKE_CXX_COMPILER_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"\" FORCE)")
endif()
if(DEFINED CMAKE_NM AND NOT "${CMAKE_NM}" STREQUAL "")
	_bm_path_normalize(_bm_nm "${CMAKE_NM}")
	_bm_tc_export_raw(
		"set(CMAKE_NM \"${_bm_nm}\" CACHE FILEPATH \"BuildMaster NM\" FORCE)")
endif()