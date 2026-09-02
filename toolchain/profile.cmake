# =============================================================================
# toolchain/profile.cmake — load named profiles into BM_TC_*
# =============================================================================

## @brief Infer gcc|clang|clang-cl|msvc from this process compiler.
## @param[out] out_var Parent-scope profile name.
## @note Used when a component has no TOOLCHAIN= (inherit / extra tools).
##       clang-cl before clang. cl.exe → msvc. Everything else gcc.
function(_bm_tc_infer_profile out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_infer_profile")
	set(_name "gcc")
	if(CMAKE_C_COMPILER MATCHES "clang-cl" OR CMAKE_CXX_COMPILER MATCHES "clang-cl")
		set(_name "clang-cl")
	elseif(CMAKE_C_COMPILER MATCHES "clang" OR CMAKE_CXX_COMPILER MATCHES "clang"
			OR CMAKE_C_COMPILER_ID STREQUAL "Clang"
			OR CMAKE_C_COMPILER_ID STREQUAL "AppleClang")
		set(_name "clang")
	elseif(MSVC OR CMAKE_C_COMPILER MATCHES "cl\\.exe$"
			OR CMAKE_C_COMPILER_ID STREQUAL "MSVC")
		set(_name "msvc")
	endif()
	set(${out_var} "${_name}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG "infer profile '${_name}'")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_infer_profile")
endfunction()

## @brief Resolve one profile tool to an absolute path or FATAL.
## @param[in]  label   Word in the error (`compiler`, `archiver`, `linker`).
## @param[in]  name    Profile id (for the message).
## @param[in]  names   `find_program` NAMES (first hit wins).
## @param[out] out_var Absolute path.
function(_bm_tc_require_program label name names out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_require_program(${label})")
	find_program(_bm_prog NAMES ${names})
	if(NOT _bm_prog)
		_bm_log_message(TOOLCHAIN FATAL
			"toolchain '${name}': missing ${label} (${names})")
	endif()
	_bm_path_normalize(_bm_prog "${_bm_prog}")
	set(${out_var} "${_bm_prog}" PARENT_SCOPE)
	unset(_bm_prog CACHE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_require_program(${label})")
endfunction()

## @brief Load a toolchain profile into `BM_TC_*` in the caller scope.
## @param[in] name Normalized toolchain name (`_bm_tc_validate`).
## @note Includes `toolchain/profiles/<name>.cmake`. Then resolves
##       compiler / archiver / linker to absolute paths. Missing tool
##       is FATAL — no silent fallback to the parent job.
## @note Triple:
##       gcc      → Linux: bfd + binutils `ar`
##                  Darwin: Homebrew gcc-N + cctools `ld`/`ar` (no BFD)
##       clang    → Linux: lld + `llvm-ar`
##                  Darwin: cctools `ld` + `ar`
##       clang-cl → lld-link + `llvm-lib`
##       msvc     → link.exe + lib.exe
## @note Empty `name` or a missing profile file is FATAL.
function(_bm_tc_load_profile name)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_load_profile")
	if(name STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL "_bm_tc_load_profile: empty name")
	endif()

	set(_profile_file "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}/${name}.cmake")
	if(NOT EXISTS "${_profile_file}")
		_bm_log_message(TOOLCHAIN FATAL
			"Missing toolchain profile file: ${_profile_file}"
		)
	endif()

	include("${_profile_file}")

	_bm_tc_require_program("C compiler" "${name}"
		"${BM_TC_C_COMPILER}" BM_TC_C_COMPILER)
	_bm_tc_require_program("C++ compiler" "${name}"
		"${BM_TC_CXX_COMPILER}" BM_TC_CXX_COMPILER)
	_bm_tc_require_program("archiver" "${name}"
		"${BM_TC_AR}" BM_TC_AR)

	if(name STREQUAL "gcc")
		if(APPLE)
			_bm_tc_require_program("linker" "${name}"
				"ld;ld64" BM_TC_LINKER)
		else()
			_bm_tc_require_program("linker" "${name}"
				"ld.bfd;ld" BM_TC_LINKER)
		endif()
	elseif(name STREQUAL "clang")
		if(APPLE)
			_bm_tc_require_program("linker" "${name}"
				"ld;ld64" BM_TC_LINKER)
		else()
			_bm_tc_require_program("linker" "${name}"
				"ld.lld;lld" BM_TC_LINKER)
		endif()
	elseif(name STREQUAL "clang-cl")
		if(COMMAND _bm_tc_resolve_msvc_tool)
			_bm_tc_resolve_msvc_tool(BM_TC_LINKER "${BM_TC_LINKER}")
			_bm_tc_resolve_msvc_tool(BM_TC_AR "${BM_TC_AR}")
		endif()
		_bm_tc_require_program("linker" "${name}"
			"${BM_TC_LINKER};lld-link" BM_TC_LINKER)
		_bm_tc_require_program("archiver" "${name}"
			"${BM_TC_AR};llvm-lib" BM_TC_AR)
	elseif(name STREQUAL "msvc")
		if(COMMAND _bm_tc_resolve_msvc_tool)
			_bm_tc_resolve_msvc_tool(BM_TC_LINKER "${BM_TC_LINKER}")
			_bm_tc_resolve_msvc_tool(BM_TC_AR "${BM_TC_AR}")
			_bm_tc_resolve_msvc_tool(BM_TC_C_COMPILER "${BM_TC_C_COMPILER}")
			_bm_tc_resolve_msvc_tool(BM_TC_CXX_COMPILER "${BM_TC_CXX_COMPILER}")
		endif()
		_bm_tc_require_program("linker" "${name}"
			"${BM_TC_LINKER};link;link.exe" BM_TC_LINKER)
		_bm_tc_require_program("archiver" "${name}"
			"${BM_TC_AR};lib;lib.exe" BM_TC_AR)
	endif()

	if(NOT "${BM_TC_RANLIB}" STREQUAL "")
		find_program(_bm_ranlib NAMES ${BM_TC_RANLIB})
		if(_bm_ranlib)
			_bm_path_normalize(BM_TC_RANLIB "${_bm_ranlib}")
		endif()
		unset(_bm_ranlib CACHE)
	endif()

	if(NOT "${BM_TC_NM}" STREQUAL "")
		find_program(_bm_nm NAMES ${BM_TC_NM})
		if(_bm_nm)
			_bm_path_normalize(BM_TC_NM "${_bm_nm}")
		endif()
		unset(_bm_nm CACHE)
	endif()

	set(BM_TC_C_COMPILER "${BM_TC_C_COMPILER}" PARENT_SCOPE)
	set(BM_TC_CXX_COMPILER "${BM_TC_CXX_COMPILER}" PARENT_SCOPE)
	set(BM_TC_LINKER_TYPE "${BM_TC_LINKER_TYPE}" PARENT_SCOPE)
	set(BM_TC_LINKER "${BM_TC_LINKER}" PARENT_SCOPE)
	set(BM_TC_AR "${BM_TC_AR}" PARENT_SCOPE)
	set(BM_TC_RANLIB "${BM_TC_RANLIB}" PARENT_SCOPE)
	set(BM_TC_NM "${BM_TC_NM}" PARENT_SCOPE)
	set(BM_TC_FORCE_LLD "${BM_TC_FORCE_LLD}" PARENT_SCOPE)
	set(BM_TC_FUSE_LD "${BM_TC_FUSE_LD}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG
		"Loaded profile ${name} cc=${BM_TC_C_COMPILER} ar=${BM_TC_AR} ld=${BM_TC_LINKER}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_load_profile")
endfunction()
