include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief Validate and normalize a BuildMaster toolchain name.
## @param[out] out_normalized Parent-scope variable receiving the lowercased
##            name, or an empty string when @p input is empty (no override).
## @param[in] input Raw toolchain name from the component DSL (may be empty).
## @note Empty input means “use the parent toolchain” and is not an error.
##       Unknown names or platform-incompatible names produce FATAL_ERROR and
##       list the known toolchains.
## @note BUILDMASTER_KNOWN_TOOLCHAINS may arrive as a CMake list or as a
##       newline/space-separated string from a nested toolchain dump. Both
##       forms are accepted.
function(buildmaster_validate_toolchain out_normalized input)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_validate_toolchain")
	string(STRIP "${input}" _t)
	string(TOLOWER "${_t}" _t)

	if(_t STREQUAL "")
		set(${out_normalized} "" PARENT_SCOPE)
		buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_validate_toolchain")
		return()
	endif()

	set(_known "${BUILDMASTER_KNOWN_TOOLCHAINS}")
	string(REPLACE "\r" "" _known "${_known}")
	string(REPLACE "\n" ";" _known "${_known}")
	string(REPLACE "," ";" _known "${_known}")
	string(REPLACE " " ";" _known "${_known}")
	list(FILTER _known EXCLUDE REGEX "^$")

	list(FIND _known "${_t}" _idx)
	if(_idx EQUAL -1)
		list(JOIN _known ", " _known_pretty)
		buildmaster_message(TOOLCHAIN FATAL
			"Unknown TOOLCHAIN '${input}'. Known toolchains: ${_known_pretty}"
		)
	endif()

	if(_t STREQUAL "msvc" OR _t STREQUAL "clang-cl")
		if(NOT WIN32)
			list(JOIN _known ", " _known_pretty)
			buildmaster_message(TOOLCHAIN FATAL
				"TOOLCHAIN '${_t}' is only valid on Windows. Known toolchains: ${_known_pretty}"
			)
		endif()
	endif()

	if(_t STREQUAL "gcc" OR _t STREQUAL "clang")
		if(WIN32)
			buildmaster_message(TOOLCHAIN FATAL
				"TOOLCHAIN '${_t}' is not supported on Windows. On Windows use: clang-cl, msvc"
			)
		endif()
	endif()

	set(${out_normalized} "${_t}" PARENT_SCOPE)
	buildmaster_message(TOOLCHAIN DEBUG "Validated TOOLCHAIN=${_t}")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_validate_toolchain")
endfunction()

## @brief Load a toolchain profile into BM_TC_* variables in the caller scope.
## @param[in] name Normalized toolchain name (from buildmaster_validate_toolchain).
## @note Includes toolchain/profiles/<name>.cmake which sets BM_TC_C_COMPILER,
##       BM_TC_CXX_COMPILER, BM_TC_LINKER_TYPE, BM_TC_LINKER, BM_TC_AR,
##       BM_TC_RANLIB, BM_TC_NM, and related fields. Values are exported to the
##       caller with PARENT_SCOPE (required because CMake functions isolate scope).
##       Does not modify the parent project toolchain or the global env runner.
function(buildmaster_load_toolchain_profile name)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_load_toolchain_profile")
	if(name STREQUAL "")
		buildmaster_message(TOOLCHAIN FATAL "buildmaster_load_toolchain_profile: empty name")
	endif()

	set(_profile_file "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}/${name}.cmake")
	if(NOT EXISTS "${_profile_file}")
		buildmaster_message(TOOLCHAIN FATAL
			"Missing toolchain profile file: ${_profile_file}"
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
	buildmaster_message(TOOLCHAIN DEBUG "Loaded profile ${name}")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_load_toolchain_profile")
endfunction()

## @brief Strip linker-flag tokens that are invalid for a given toolchain.
## @param[out] out_flags Parent-scope variable receiving the cleaned flags string.
## @param[in] flags Original linker flags (may be empty).
## @param[in] toolchain_name Normalized toolchain name (`gcc`, `clang`,
##            `clang-cl`, `msvc`).
## @note Does not clear the entire flag string. Only removes known-incoherent
##       tokens for that profile. Unknown tokens are preserved.
function(buildmaster_clean_ldflags out_flags flags toolchain_name)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_clean_ldflags")
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
	elseif(toolchain_name STREQUAL "clang-cl")
		# MSVC LTCG link flags are ignored / wrong with lld-link
		foreach(_tok
			"/LTCG"
			"/LTCG:INCREMENTAL"
			"/LTCG:STATUS"
			"/LTCG:OFF"
			"/GL"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	endif()

	set(${out_flags} "${_f}" PARENT_SCOPE)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_clean_ldflags")
endfunction()

## @brief Strip compile-flag tokens that are invalid for a given toolchain.
## @param[out] out_flags Parent-scope variable receiving the cleaned flags string.
## @param[in] flags Original C or CXX flags (may be empty).
## @param[in] toolchain_name Normalized toolchain name (`gcc`, `clang`,
##            `clang-cl`, `msvc`).
## @note Does not clear the entire flag string. When targeting `msvc`, removes
##       known Clang/LLVM-only switches. When targeting `clang-cl`, removes
##       MSVC whole-program LTCG compile switches (`/GL`) that clang-cl ignores
##       with “unknown argument ignored”.
function(buildmaster_clean_cflags out_flags flags toolchain_name)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_clean_cflags")
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
	elseif(toolchain_name STREQUAL "clang-cl")
		foreach(_tok
			"/GL"
			"/LTCG"
			"/LTCG:INCREMENTAL"
			"/LTCG:STATUS"
			"/LTCG:OFF"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	endif()

	set(${out_flags} "${_f}" PARENT_SCOPE)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_clean_cflags")
endfunction()

## @brief Map linker type/path to a driver-safe -fuse-ld= flag for Meson/CMake.
## @param[out] out_flag Parent-scope variable receiving e.g. "-fuse-ld=lld",
##            or empty when the system default linker must be used.
## @param[in] linker_type Optional CMAKE_LINKER_TYPE / BM_TC_LINKER_TYPE
##            (`LLD`, `MSVC`, …). May be empty.
## @param[in] linker Optional CMAKE_LINKER / BM_TC_LINKER path or short name.
## @note GCC rejects absolute paths such as -fuse-ld=/usr/bin/ld. Only emit
##       flavor names the compiler driver understands (lld, gold, mold, bfd,
##       link). System `ld` and unknown paths yield an empty flag so Meson
##       keeps the default linker.
function(buildmaster_fuse_ld_flag out_flag linker_type linker)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_fuse_ld_flag")
	set(_flag "")
	string(STRIP "${linker_type}" _lt)
	string(TOUPPER "${_lt}" _lt)
	string(STRIP "${linker}" _lnk)

	if(_lt STREQUAL "LLD")
		if(WIN32)
			set(_flag "-fuse-ld=lld-link")
		else()
			set(_flag "-fuse-ld=lld")
		endif()
	elseif(_lt STREQUAL "MSVC")
		set(_flag "-fuse-ld=link")
	elseif(NOT _lnk STREQUAL "")
		get_filename_component(_base "${_lnk}" NAME)
		string(TOLOWER "${_base}" _base)
		string(REGEX REPLACE "\\.exe$" "" _base "${_base}")

		if(_base STREQUAL "lld" OR _base STREQUAL "ld.lld")
			if(WIN32)
				set(_flag "-fuse-ld=lld-link")
			else()
				set(_flag "-fuse-ld=lld")
			endif()
		elseif(_base STREQUAL "lld-link")
			set(_flag "-fuse-ld=lld-link")
		elseif(_base STREQUAL "gold" OR _base STREQUAL "ld.gold")
			set(_flag "-fuse-ld=gold")
		elseif(_base STREQUAL "mold")
			set(_flag "-fuse-ld=mold")
		elseif(_base STREQUAL "bfd" OR _base STREQUAL "ld.bfd")
			set(_flag "-fuse-ld=bfd")
		elseif(_base STREQUAL "link")
			if(WIN32)
				set(_flag "-fuse-ld=link")
			endif()
		endif()
		# basename "ld" or unknown absolute paths: leave empty
	endif()

	set(${out_flag} "${_flag}" PARENT_SCOPE)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_fuse_ld_flag")
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
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_resolve_msvc_tool")
	if(tool_name STREQUAL "")
		set(${out_var} "" PARENT_SCOPE)
		buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_resolve_msvc_tool")
		return()
	endif()

	if(IS_ABSOLUTE "${tool_name}" AND EXISTS "${tool_name}")
		normalize_cmake_path(_abs "${tool_name}")
		set(${out_var} "${_abs}" PARENT_SCOPE)
		buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_resolve_msvc_tool")
		return()
	endif()

	# Unique cache key per tool — shared _bm_found would stick on the first hit (e.g. cl).
	string(MAKE_C_IDENTIFIER "${tool_name}" _bm_tool_id)
	set(_bm_cache_var "_BM_MSVC_TOOL_${_bm_tool_id}")

	find_program(${_bm_cache_var} NAMES "${tool_name}" "${tool_name}.exe")
	if(${_bm_cache_var})
		normalize_cmake_path(_bm_found "${${_bm_cache_var}}")
		set(${out_var} "${_bm_found}" PARENT_SCOPE)
		buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_resolve_msvc_tool")
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
					buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_resolve_msvc_tool")
					return()
				endif()
			endforeach()
		endif()
	endif()

	set(${out_var} "${tool_name}" PARENT_SCOPE)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_resolve_msvc_tool")
endfunction()

# =============================================================================
# Toolchain file registry (single source of truth for parent + component dumps)
# =============================================================================

## @brief Clear the in-memory toolchain export registry.
## @note Call once at the start of a BuildMaster bootstrap before any
##       buildmaster_toolchain_export* calls. Safe to call more than once.
function(buildmaster_toolchain_reset)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_toolchain_reset")
	set_property(GLOBAL PROPERTY BUILDMASTER_TOOLCHAIN_LINES "")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_toolchain_reset")
endfunction()

## @brief Register a simple string assignment for the toolchain file dump.
## @param[in] name  CMake variable name (unquoted identifier).
## @param[in] value Value written as set(name "value"). Backslashes should
##            already be normalized (prefer normalize_cmake_path for paths).
## @note Appends one line to the global BUILDMASTER_TOOLCHAIN_LINES property.
##       Does not write the toolchain file; call buildmaster_toolchain_write.
function(buildmaster_toolchain_export name value)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_toolchain_export")
	if("${name}" STREQUAL "")
		buildmaster_message(TOOLCHAIN FATAL "buildmaster_toolchain_export: empty name")
	endif()
	string(REPLACE "\\" "/" _bm_tc_val "${value}")
	string(REPLACE "\"" "\\\"" _bm_tc_val "${_bm_tc_val}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_TOOLCHAIN_LINES
		"set(${name} \"${_bm_tc_val}\")")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_toolchain_export")
endfunction()

## @brief Register a pre-formatted CMake line for the toolchain file dump.
## @param[in] line Full line without trailing newline (e.g. a CACHE FORCE
##            assignment, or set(ENV_RUNNER ${ENV_RUNNER}) for list expansion).
## @note Use when quoting rules differ from buildmaster_toolchain_export.
##       Empty lines are ignored. Does not write the file until
##       buildmaster_toolchain_write is called.
function(buildmaster_toolchain_export_raw line)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_toolchain_export_raw")
	if("${line}" STREQUAL "")
		buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_toolchain_export_raw")
		return()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_TOOLCHAIN_LINES "${line}")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_toolchain_export_raw")
endfunction()

## @brief Write all registered toolchain lines to a file.
## @param[in] path Absolute or CMake-style path of the output .cmake file.
## @note Overwrites @p path. Creates parent directories if needed. Order of
##       lines matches registration order. Component TOOLCHAIN overlays should
##       call buildmaster_toolchain_write_component instead.
function(buildmaster_toolchain_write path)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_toolchain_write")
	if("${path}" STREQUAL "")
		buildmaster_message(TOOLCHAIN FATAL "buildmaster_toolchain_write: empty path")
	endif()
	normalize_cmake_path(_bm_tc_out "${path}")
	get_filename_component(_bm_tc_dir "${_bm_tc_out}" DIRECTORY)
	if(NOT _bm_tc_dir STREQUAL "")
		file(MAKE_DIRECTORY "${_bm_tc_dir}")
	endif()

	get_property(_bm_tc_lines GLOBAL PROPERTY BUILDMASTER_TOOLCHAIN_LINES)
	set(_bm_tc_body
		"# Auto-generated by BuildMaster - do not edit directly\n")
	foreach(_bm_tc_line IN LISTS _bm_tc_lines)
		string(APPEND _bm_tc_body "${_bm_tc_line}\n")
	endforeach()
	file(WRITE "${_bm_tc_out}" "${_bm_tc_body}")
	buildmaster_message(TOOLCHAIN DEBUG "Wrote toolchain dump ${_bm_tc_out}")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_toolchain_write")
endfunction()

# Write a component toolchain file: parent registry snapshot + profile overlay.
#
# The generated file is the active toolchain while that component (and any nested
# create_* stages generated under it) runs. After the registry snapshot, append
# CACHE FORCE lines for the loaded profile (BM_TC_*) and set
# BUILDMASTER_TOOLCHAIN_FILE to this file's path so children without an explicit
# TOOLCHAIN argument keep propagating the same modified toolchain downward
# instead of falling back to the parent dump.
#
# path            - Absolute path of the component toolchain.cmake to write.
# toolchain_name  - Profile name (for comments only; tools come from BM_TC_*).
macro(buildmaster_toolchain_write_component path toolchain_name)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_toolchain_write_component")
	buildmaster_toolchain_write("${path}")

	normalize_cmake_path(_bm_tc_self "${path}")

	set(_bm_tc_overlay "")
	string(APPEND _bm_tc_overlay
		"\n"
		"# Component TOOLCHAIN=${toolchain_name} overlay (compilers / binutils)\n"
		"# Active toolchain for this component and nested create_* without TOOLCHAIN.\n"
		"set(BUILDMASTER_TOOLCHAIN_FILE \"${_bm_tc_self}\")\n"
	)

	if(DEFINED BM_TC_C_COMPILER AND NOT BM_TC_C_COMPILER STREQUAL "")
		normalize_cmake_path(_bm_tc_c "${BM_TC_C_COMPILER}")
		string(APPEND _bm_tc_overlay "set(CMAKE_C_COMPILER \"${_bm_tc_c}\" CACHE FILEPATH \"\" FORCE)\n")
	endif()
	if(DEFINED BM_TC_CXX_COMPILER AND NOT BM_TC_CXX_COMPILER STREQUAL "")
		normalize_cmake_path(_bm_tc_cxx "${BM_TC_CXX_COMPILER}")
		string(APPEND _bm_tc_overlay "set(CMAKE_CXX_COMPILER \"${_bm_tc_cxx}\" CACHE FILEPATH \"\" FORCE)\n")
	endif()
	if(DEFINED BM_TC_LINKER_TYPE AND NOT BM_TC_LINKER_TYPE STREQUAL "")
		string(APPEND _bm_tc_overlay "set(CMAKE_LINKER_TYPE \"${BM_TC_LINKER_TYPE}\" CACHE STRING \"\" FORCE)\n")
	endif()
	if(DEFINED BM_TC_LINKER AND NOT BM_TC_LINKER STREQUAL "")
		normalize_cmake_path(_bm_tc_link "${BM_TC_LINKER}")
		string(APPEND _bm_tc_overlay "set(CMAKE_LINKER \"${_bm_tc_link}\" CACHE FILEPATH \"\" FORCE)\n")
		string(APPEND _bm_tc_overlay "set(CMAKE_C_COMPILER_LINKER \"${_bm_tc_link}\" CACHE FILEPATH \"\" FORCE)\n")
		string(APPEND _bm_tc_overlay "set(CMAKE_CXX_COMPILER_LINKER \"${_bm_tc_link}\" CACHE FILEPATH \"\" FORCE)\n")
	endif()
	if(DEFINED BM_TC_AR AND NOT BM_TC_AR STREQUAL "")
		normalize_cmake_path(_bm_tc_ar "${BM_TC_AR}")
		string(APPEND _bm_tc_overlay "set(CMAKE_AR \"${_bm_tc_ar}\" CACHE FILEPATH \"\" FORCE)\n")
		string(APPEND _bm_tc_overlay "set(CMAKE_C_COMPILER_AR \"${_bm_tc_ar}\" CACHE FILEPATH \"\" FORCE)\n")
		string(APPEND _bm_tc_overlay "set(CMAKE_CXX_COMPILER_AR \"${_bm_tc_ar}\" CACHE FILEPATH \"\" FORCE)\n")
	endif()
	if(DEFINED BM_TC_NM AND NOT BM_TC_NM STREQUAL "")
		string(APPEND _bm_tc_overlay "set(CMAKE_NM \"${BM_TC_NM}\" CACHE FILEPATH \"\" FORCE)\n")
	endif()
	if(DEFINED BM_TC_RANLIB AND NOT BM_TC_RANLIB STREQUAL "")
		string(APPEND _bm_tc_overlay "set(CMAKE_RANLIB \"${BM_TC_RANLIB}\" CACHE FILEPATH \"\" FORCE)\n")
	endif()

	# Nested Meson under this component should use the profile native file
	if(COMMAND buildmaster_get_meson_native_file)
		buildmaster_get_meson_native_file(_bm_tc_nf TOOLCHAIN "${toolchain_name}")
		if(NOT _bm_tc_nf STREQUAL "")
			normalize_cmake_path(_bm_tc_nf "${_bm_tc_nf}")
			string(APPEND _bm_tc_overlay
				"set(BUILDMASTER_MESON_NATIVE_FILE \"${_bm_tc_nf}\")\n")
		endif()
	endif()

	file(APPEND "${path}" "${_bm_tc_overlay}")
	unset(_bm_tc_overlay)
	unset(_bm_tc_self)
	buildmaster_message(TOOLCHAIN DEBUG "Wrote component toolchain overlay ${path}")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_toolchain_write_component")
endmacro()
