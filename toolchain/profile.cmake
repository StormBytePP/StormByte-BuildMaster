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

## @brief Human line for who asked a profile.
## @param[out] out_var Parent-scope text.
## @param[in]  who     `parent` or `component:<id>` / `meta:<id>` /
##            `component:<id>:meta:<mid>`.
function(_bm_tc_who_line out_var who)
	_bm_tc_infer_profile(_parent)
	set(_cc "${CMAKE_C_COMPILER}")
	if(_cc STREQUAL "")
		set(_cc "${CMAKE_CXX_COMPILER}")
	endif()
	if("${who}" STREQUAL "" OR "${who}" STREQUAL "parent")
		set(${out_var}
			"Parent toolchain '${_parent}' is required by the parent job (CMAKE_C_COMPILER=${_cc})."
			PARENT_SCOPE)
	elseif(who MATCHES "^component:([^:]+):meta:(.+)$")
		set(${out_var}
			"Toolchain is required by component '${CMAKE_MATCH_1}' (inherited from meta '${CMAKE_MATCH_2}'). Parent job is '${_parent}' (CMAKE_C_COMPILER=${_cc})."
			PARENT_SCOPE)
	elseif(who MATCHES "^component:(.+)$")
		set(${out_var}
			"Toolchain is required by component '${CMAKE_MATCH_1}' (TOOLCHAIN=). Parent job is '${_parent}' (CMAKE_C_COMPILER=${_cc})."
			PARENT_SCOPE)
	elseif(who MATCHES "^meta:(.+)$")
		set(${out_var}
			"Toolchain is required by meta '${CMAKE_MATCH_1}' (TOOLCHAIN=). Parent job is '${_parent}' (CMAKE_C_COMPILER=${_cc})."
			PARENT_SCOPE)
	else()
		set(${out_var}
			"Toolchain is required (${who}). Parent job is '${_parent}' (CMAKE_C_COMPILER=${_cc})."
			PARENT_SCOPE)
	endif()
endfunction()

## @brief Resolve one profile tool to an absolute path or FATAL.
## @param[in]  label   Word in the error (`C compiler`, `archiver`, `linker`).
## @param[in]  name    Profile id (for the message).
## @param[in]  names   `find_program` NAMES (first hit wins).
## @param[out] out_var Absolute path.
## @param[in]  who     Optional ARGV4 — see `_bm_tc_who_line`. Default `parent`.
## @note Missing tool is FATAL. No silent fallback to the parent job.
function(_bm_tc_require_program label name names out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_require_program(${label})")
	set(_who "parent")
	if(ARGC GREATER 4 AND NOT "${ARGV4}" STREQUAL "")
		set(_who "${ARGV4}")
	endif()
	find_program(_bm_prog NAMES ${names})
	if(NOT _bm_prog)
		_bm_tc_who_line(_why "${_who}")
		string(REPLACE ";" " or " _pretty "${names}")
		_bm_log_message(TOOLCHAIN FATAL
			"${_why}\nMissing ${label} for profile '${name}': ${_pretty}.\nInstall the '${name}' toolchain or drop TOOLCHAIN=${name} on that id.")
	endif()
	_bm_path_normalize(_bm_prog "${_bm_prog}")
	set(${out_var} "${_bm_prog}" PARENT_SCOPE)
	unset(_bm_prog CACHE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_require_program(${label})")
endfunction()

## @brief Load a toolchain profile into `BM_TC_*` in the caller scope.
## @param[in] name Normalized toolchain name (`_bm_tc_validate`).
## @param[in] who  Optional ARGV1 — demand origin for FATAL text.
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
	set(_who "parent")
	if(ARGC GREATER 1 AND NOT "${ARGV1}" STREQUAL "")
		set(_who "${ARGV1}")
	endif()
	if(name STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL "_bm_tc_load_profile: empty name")
	endif()

	set(_profile_file "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}/${name}.cmake")
	if(NOT EXISTS "${_profile_file}")
		_bm_tc_who_line(_why "${_who}")
		_bm_log_message(TOOLCHAIN FATAL
			"${_why}\nMissing toolchain profile file: ${_profile_file}\nThis is a BuildMaster install problem, not a missing compiler on PATH."
		)
	endif()

	include("${_profile_file}")

	_bm_tc_require_program("C compiler" "${name}"
		"${BM_TC_C_COMPILER}" BM_TC_C_COMPILER "${_who}")
	_bm_tc_require_program("C++ compiler" "${name}"
		"${BM_TC_CXX_COMPILER}" BM_TC_CXX_COMPILER "${_who}")
	_bm_tc_require_program("archiver" "${name}"
		"${BM_TC_AR}" BM_TC_AR "${_who}")

	if(name STREQUAL "gcc")
		if(APPLE)
			_bm_tc_require_program("linker" "${name}"
				"ld;ld64" BM_TC_LINKER "${_who}")
		else()
			_bm_tc_require_program("linker" "${name}"
				"ld.bfd;ld" BM_TC_LINKER "${_who}")
		endif()
	elseif(name STREQUAL "clang")
		if(APPLE)
			_bm_tc_require_program("linker" "${name}"
				"ld;ld64" BM_TC_LINKER "${_who}")
		else()
			_bm_tc_require_program("linker" "${name}"
				"ld.lld;lld" BM_TC_LINKER "${_who}")
		endif()
	elseif(name STREQUAL "clang-cl")
		if(COMMAND _bm_tc_resolve_msvc_tool)
			_bm_tc_resolve_msvc_tool(BM_TC_LINKER "${BM_TC_LINKER}")
			_bm_tc_resolve_msvc_tool(BM_TC_AR "${BM_TC_AR}")
		endif()
		_bm_tc_require_program("linker" "${name}"
			"${BM_TC_LINKER};lld-link" BM_TC_LINKER "${_who}")
		_bm_tc_require_program("archiver" "${name}"
			"${BM_TC_AR};llvm-lib" BM_TC_AR "${_who}")
	elseif(name STREQUAL "msvc")
		if(COMMAND _bm_tc_resolve_msvc_tool)
			_bm_tc_resolve_msvc_tool(BM_TC_LINKER "${BM_TC_LINKER}")
			_bm_tc_resolve_msvc_tool(BM_TC_AR "${BM_TC_AR}")
			_bm_tc_resolve_msvc_tool(BM_TC_C_COMPILER "${BM_TC_C_COMPILER}")
			_bm_tc_resolve_msvc_tool(BM_TC_CXX_COMPILER "${BM_TC_CXX_COMPILER}")
		endif()
		_bm_tc_require_program("linker" "${name}"
			"${BM_TC_LINKER};link;link.exe" BM_TC_LINKER "${_who}")
		_bm_tc_require_program("archiver" "${name}"
			"${BM_TC_AR};lib;lib.exe" BM_TC_AR "${_who}")
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

## @brief Load profile @p name once and write its Meson native file.
## @param[in] name Normalized profile (`gcc` / `clang` / `clang-cl` / `msvc`).
## @param[in] who  Demand origin for FATAL text (`_bm_tc_who_line`).
## @note Second call is a no-op. Empty name is a no-op (inherit parent).
##       Marks the profile enabled *before* writing the native file so
##       `_bm_tc_meson_native_ld` → demand cannot recurse.
##       Does not initialize any other known profile.
function(_bm_tc_demand_profile name who)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_demand_profile(${name})")
	if("${name}" STREQUAL "")
		_bm_log_message(TOOLCHAIN LOWLEVEL
			"Exiting _bm_tc_demand_profile (empty)")
		return()
	endif()
	_bm_tc_validate(_name "${name}")
	if("${_name}" STREQUAL "")
		_bm_log_message(TOOLCHAIN LOWLEVEL
			"Exiting _bm_tc_demand_profile (empty after validate)")
		return()
	endif()

	get_property(_enabled GLOBAL PROPERTY BUILDMASTER_TC_PROFILES_ENABLED)
	set(_hit -1)
	if(_enabled)
		list(FIND _enabled "${_name}" _hit)
	endif()
	if(NOT _hit EQUAL -1)
		_bm_log_message(TOOLCHAIN LOWLEVEL
			"Exiting _bm_tc_demand_profile(${_name}) (enabled)")
		return()
	endif()

	if("${who}" STREQUAL "")
		set(who "parent")
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_TC_PROFILES_ENABLED "${_name}")
	set_property(GLOBAL PROPERTY BUILDMASTER_TC_PROFILE_WHO_${_name} "${who}")
	_bm_log_message(TOOLCHAIN STATUS "Setting up toolchain: ${_name}" 1)
	_bm_tc_load_profile("${_name}" "${who}")
	if(COMMAND _bm_tc_write_meson_native_file
			AND DEFINED BUILDMASTER_SCRIPTSDIR
			AND NOT BUILDMASTER_SCRIPTSDIR STREQUAL "")
		_bm_tc_meson_native_resolve_launcher(_launch)
		_bm_tc_write_meson_native_file("${_name}"
			"${BM_TC_C_COMPILER}" "${BM_TC_CXX_COMPILER}"
			LAUNCHER "${_launch}")
	endif()
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Exiting _bm_tc_demand_profile(${_name})")
endfunction()
