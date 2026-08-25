file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
	"set(BUILDMASTER_TOOLS_CMAKE_SRCDIR \"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}\")\n"
	"set(BUILDMASTER_SCRIPTS_CMAKEDIR \"${BUILDMASTER_SCRIPTS_CMAKEDIR}\")\n"
	"set(ENV_CMAKE_COMMAND ${ENV_CMAKE_COMMAND})\n"
	"set(ENV_CMAKE_SILENT_COMMAND ${ENV_CMAKE_SILENT_COMMAND})\n"
	"set(ENV_CMAKE_COMPILE_COMMAND ${ENV_CMAKE_COMPILE_COMMAND})\n"
)

# Propagate linker selection from parent (MSVC link.exe, or LLD / lld-link for clang-cl).
# Only write non-empty values so Linux/macOS toolchains stay untouched when unset.
# Paths must be CMake-style (forward slashes) via normalize_cmake_path.
if(DEFINED CMAKE_LINKER_TYPE AND NOT "${CMAKE_LINKER_TYPE}" STREQUAL "")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_LINKER_TYPE \"${CMAKE_LINKER_TYPE}\" CACHE STRING \"BuildMaster linker type\" FORCE)\n"
	)
endif()

if(DEFINED CMAKE_LINKER AND NOT "${CMAKE_LINKER}" STREQUAL "")
	normalize_cmake_path(_bm_linker "${CMAKE_LINKER}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster linker\" FORCE)\n"
		"set(CMAKE_C_COMPILER_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster C linker\" FORCE)\n"
		"set(CMAKE_CXX_COMPILER_LINKER \"${_bm_linker}\" CACHE FILEPATH \"BuildMaster CXX linker\" FORCE)\n"
	)
endif()

if(DEFINED CMAKE_C_COMPILER_LINKER AND NOT "${CMAKE_C_COMPILER_LINKER}" STREQUAL ""
		AND (NOT DEFINED CMAKE_LINKER OR "${CMAKE_LINKER}" STREQUAL ""))
	normalize_cmake_path(_bm_c_linker "${CMAKE_C_COMPILER_LINKER}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_C_COMPILER_LINKER \"${_bm_c_linker}\" CACHE FILEPATH \"BuildMaster C linker\" FORCE)\n"
	)
endif()

if(DEFINED CMAKE_CXX_COMPILER_LINKER AND NOT "${CMAKE_CXX_COMPILER_LINKER}" STREQUAL ""
		AND (NOT DEFINED CMAKE_LINKER OR "${CMAKE_LINKER}" STREQUAL ""))
	normalize_cmake_path(_bm_cxx_linker "${CMAKE_CXX_COMPILER_LINKER}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_CXX_COMPILER_LINKER \"${_bm_cxx_linker}\" CACHE FILEPATH \"BuildMaster CXX linker\" FORCE)\n"
	)
endif()

if(DEFINED CMAKE_MT AND NOT "${CMAKE_MT}" STREQUAL "" AND NOT "${CMAKE_MT}" STREQUAL "mt")
	normalize_cmake_path(_bm_mt "${CMAKE_MT}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_MT \"${_bm_mt}\" CACHE FILEPATH \"BuildMaster mt\" FORCE)\n"
	)
elseif(DEFINED CMAKE_MT AND "${CMAKE_MT}" STREQUAL "mt")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_MT \"mt\" CACHE FILEPATH \"BuildMaster mt\" FORCE)\n"
	)
endif()

if(DEFINED CMAKE_EXE_LINKER_FLAGS AND NOT "${CMAKE_EXE_LINKER_FLAGS}" STREQUAL "")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_EXE_LINKER_FLAGS \"${CMAKE_EXE_LINKER_FLAGS}\" CACHE STRING \"\" FORCE)\n"
	)
endif()
if(DEFINED CMAKE_SHARED_LINKER_FLAGS AND NOT "${CMAKE_SHARED_LINKER_FLAGS}" STREQUAL "")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_SHARED_LINKER_FLAGS \"${CMAKE_SHARED_LINKER_FLAGS}\" CACHE STRING \"\" FORCE)\n"
	)
endif()
if(DEFINED CMAKE_MODULE_LINKER_FLAGS AND NOT "${CMAKE_MODULE_LINKER_FLAGS}" STREQUAL "")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_MODULE_LINKER_FLAGS \"${CMAKE_MODULE_LINKER_FLAGS}\" CACHE STRING \"\" FORCE)\n"
	)
endif()

# Archiver / ranlib / nm (llvm-lib for clang-cl LTO static archives)
if(DEFINED CMAKE_AR AND NOT "${CMAKE_AR}" STREQUAL "")
	normalize_cmake_path(_bm_ar "${CMAKE_AR}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster AR\" FORCE)\n"
		"set(CMAKE_C_COMPILER_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster C AR\" FORCE)\n"
		"set(CMAKE_CXX_COMPILER_AR \"${_bm_ar}\" CACHE FILEPATH \"BuildMaster CXX AR\" FORCE)\n"
	)
endif()
if(DEFINED CMAKE_RANLIB AND NOT "${CMAKE_RANLIB}" STREQUAL "")
	normalize_cmake_path(_bm_ranlib "${CMAKE_RANLIB}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"BuildMaster RANLIB\" FORCE)\n"
		"set(CMAKE_C_COMPILER_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"\" FORCE)\n"
		"set(CMAKE_CXX_COMPILER_RANLIB \"${_bm_ranlib}\" CACHE FILEPATH \"\" FORCE)\n"
	)
endif()
if(DEFINED CMAKE_NM AND NOT "${CMAKE_NM}" STREQUAL "")
	normalize_cmake_path(_bm_nm "${CMAKE_NM}")
	file(APPEND "${BUILDMASTER_TOOLCHAIN_FILE}"
		"set(CMAKE_NM \"${_bm_nm}\" CACHE FILEPATH \"BuildMaster NM\" FORCE)\n"
	)
endif()
