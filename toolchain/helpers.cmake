## @brief Validate and normalize a BuildMaster toolchain name.
## @param[out] out_normalized Parent-scope variable receiving the lowercased
##            name, or an empty string when @p input is empty (no override).
## @param[in] input Raw toolchain name from the component DSL (may be empty).
## @note Empty input means “use the parent toolchain” and is not an error.
##       Unknown names or platform-incompatible names produce FATAL_ERROR and
##       list the known toolchains.
function(buildmaster_validate_toolchain out_normalized input)
	string(STRIP "${input}" _t)
	string(TOLOWER "${_t}" _t)

	if(_t STREQUAL "")
		set(${out_normalized} "" PARENT_SCOPE)
		return()
	endif()

	list(FIND BUILDMASTER_KNOWN_TOOLCHAINS "${_t}" _idx)
	if(_idx EQUAL -1)
		list(JOIN BUILDMASTER_KNOWN_TOOLCHAINS ", " _known)
		message(FATAL_ERROR
			"[BuildMaster] Unknown TOOLCHAIN '${input}'.\n"
			"  Known toolchains: ${_known}"
		)
	endif()

	if(_t STREQUAL "msvc" OR _t STREQUAL "clang-cl")
		if(NOT WIN32)
			list(JOIN BUILDMASTER_KNOWN_TOOLCHAINS ", " _known)
			message(FATAL_ERROR
				"[BuildMaster] TOOLCHAIN '${_t}' is only valid on Windows.\n"
				"  Known toolchains: ${_known}"
			)
		endif()
	endif()

	if(_t STREQUAL "gcc" OR _t STREQUAL "clang")
		if(WIN32)
			message(FATAL_ERROR
				"[BuildMaster] TOOLCHAIN '${_t}' is not supported on Windows.\n"
				"  On Windows use: clang-cl, msvc"
			)
		endif()
	endif()

	set(${out_normalized} "${_t}" PARENT_SCOPE)
endfunction()

## @brief Load a toolchain profile into BM_TC_* variables in the caller scope.
## @param[in] name Normalized toolchain name (from buildmaster_validate_toolchain).
## @note Includes toolchain/profiles/<name>.cmake which sets BM_TC_C_COMPILER,
##       BM_TC_CXX_COMPILER, BM_TC_LINKER_TYPE, BM_TC_LINKER, BM_TC_AR,
##       BM_TC_RANLIB, BM_TC_NM, and related fields. Values are exported to the
##       caller with PARENT_SCOPE (required because CMake functions isolate scope).
##       Does not modify the parent project toolchain or the global env runner.
function(buildmaster_load_toolchain_profile name)
	if(name STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] buildmaster_load_toolchain_profile: empty name")
	endif()

	set(_profile_file "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}/${name}.cmake")
	if(NOT EXISTS "${_profile_file}")
		message(FATAL_ERROR
			"[BuildMaster] Missing toolchain profile file:\n  ${_profile_file}"
		)
	endif()

	include("${_profile_file}")

	# Profile sets BM_TC_* in this function scope only; export to caller.
	set(BM_TC_C_COMPILER "${BM_TC_C_COMPILER}" PARENT_SCOPE)
	set(BM_TC_CXX_COMPILER "${BM_TC_CXX_COMPILER}" PARENT_SCOPE)
	set(BM_TC_LINKER_TYPE "${BM_TC_LINKER_TYPE}" PARENT_SCOPE)
	set(BM_TC_LINKER "${BM_TC_LINKER}" PARENT_SCOPE)
	set(BM_TC_AR "${BM_TC_AR}" PARENT_SCOPE)
	set(BM_TC_RANLIB "${BM_TC_RANLIB}" PARENT_SCOPE)
	set(BM_TC_NM "${BM_TC_NM}" PARENT_SCOPE)
	set(BM_TC_FORCE_LLD "${BM_TC_FORCE_LLD}" PARENT_SCOPE)
endfunction()

## @brief Strip linker-flag tokens that are invalid for a given toolchain.
## @param[out] out_flags Parent-scope variable receiving the cleaned flags string.
## @param[in] flags Original linker flags (may be empty).
## @param[in] toolchain_name Normalized toolchain name (`gcc`, `clang`,
##            `clang-cl`, `msvc`).
## @note Does not clear the entire flag string. Only removes known-incoherent
##       tokens for that profile (e.g. LLD / Clang LTO switches when the
##       target toolchain is msvc). Unknown tokens are preserved.
function(buildmaster_clean_ldflags out_flags flags toolchain_name)
	set(_f "${flags}")

	if(toolchain_name STREQUAL "msvc")
		foreach(_tok
			"-fuse-ld=lld"
			"-fuse-ld=lld-link"
			"-fuse-ld=link"
			"-flto"
			"-flto=thin"
			"-flto=full"
			"/clang:-flto"
			"/clang:-flto=thin"
			"/clang:-flto=full"
			"/clang:-fuse-ld=lld"
			"/clang:-fuse-ld=lld-link"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	endif()

	set(${out_flags} "${_f}" PARENT_SCOPE)
endfunction()

## @brief Strip compile-flag tokens that are invalid for a given toolchain.
## @param[out] out_flags Parent-scope variable receiving the cleaned flags string.
## @param[in] flags Original C or CXX flags (may be empty).
## @param[in] toolchain_name Normalized toolchain name (`gcc`, `clang`,
##            `clang-cl`, `msvc`).
## @note Does not clear the entire flag string. When targeting `msvc`, removes
##       known Clang/LLVM-only switches that may have been inherited from a
##       clang-cl parent job. MSVC-compatible and unknown tokens are preserved.
function(buildmaster_clean_cflags out_flags flags toolchain_name)
	set(_f "${flags}")

	if(toolchain_name STREQUAL "msvc")
		foreach(_tok
			"-flto"
			"-flto=thin"
			"-flto=full"
			"-fuse-ld=lld"
			"-fuse-ld=lld-link"
			"-fuse-ld=link"
			"-fthinlto-index="
			"-fwhole-program-vtables"
			"-fvirtual-function-elimination"
			"-fstrict-vtable-pointers"
			"-fno-split-lto-unit"
			"-fsplit-lto-unit"
			"/clang:-flto"
			"/clang:-flto=thin"
			"/clang:-flto=full"
			"/clang:-fuse-ld=lld"
			"/clang:-fuse-ld=lld-link"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "/clang:[^ \t]+" "" _f "${_f}")
		string(REGEX REPLACE "-fthinlto-index=[^ \t]*" "" _f "${_f}")
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	endif()

	set(${out_flags} "${_f}" PARENT_SCOPE)
endfunction()

## @brief Resolve a short MSVC tool name to an absolute path when possible.
## @param[out] out_var Parent-scope variable receiving the path (or the short
##            name if resolution fails).
## @param[in] tool_name Tool basename without extension (`cl`, `lib`, `link`).
## @note Tries find_program first, then vswhere under the latest VS install
##       (Hostx64/x64). Required for the Ninja generator: CMAKE_AR=lib is
##       otherwise treated as a path relative to the build directory.
##       Uses a unique cache variable per tool name so successive resolves
##       (cl, then lib, then link) do not reuse a stale find_program result.
function(buildmaster_resolve_msvc_tool out_var tool_name)
	if(tool_name STREQUAL "")
		set(${out_var} "" PARENT_SCOPE)
		return()
	endif()

	if(IS_ABSOLUTE "${tool_name}" AND EXISTS "${tool_name}")
		normalize_cmake_path(_abs "${tool_name}")
		set(${out_var} "${_abs}" PARENT_SCOPE)
		return()
	endif()

	# Unique cache key per tool — shared _bm_found would stick on the first hit (e.g. cl).
	string(MAKE_C_IDENTIFIER "${tool_name}" _bm_tool_id)
	set(_bm_cache_var "_BM_MSVC_TOOL_${_bm_tool_id}")

	find_program(${_bm_cache_var} NAMES "${tool_name}" "${tool_name}.exe")
	if(${_bm_cache_var})
		normalize_cmake_path(_bm_found "${${_bm_cache_var}}")
		set(${out_var} "${_bm_found}" PARENT_SCOPE)
		return()
	endif()

	set(_vswhere "")
	if(DEFINED ENV{ProgramFiles\(x86\)})
		set(_vswhere "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")
	endif()
	if(NOT EXISTS "${_vswhere}" AND DEFINED ENV{ProgramFiles})
		set(_vswhere "$ENV{ProgramFiles}/Microsoft Visual Studio/Installer/vswhere.exe")
	endif()

	if(EXISTS "${_vswhere}")
		execute_process(
			COMMAND "${_vswhere}"
				-latest
				-products *
				-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
				-find "VC/Tools/MSVC/*/bin/Hostx64/x64/${tool_name}.exe"
			OUTPUT_VARIABLE _bm_found
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_QUIET
		)
		if(_bm_found)
			string(REPLACE "\r\n" "\n" _bm_found "${_bm_found}")
			string(REPLACE "\n" ";" _bm_found_list "${_bm_found}")
			foreach(_cand IN LISTS _bm_found_list)
				string(STRIP "${_cand}" _cand)
				if(NOT _cand STREQUAL "" AND EXISTS "${_cand}")
					normalize_cmake_path(_cand "${_cand}")
					set(${out_var} "${_cand}" PARENT_SCOPE)
					return()
				endif()
			endforeach()
		endif()
	endif()

	set(${out_var} "${tool_name}" PARENT_SCOPE)
endfunction()
