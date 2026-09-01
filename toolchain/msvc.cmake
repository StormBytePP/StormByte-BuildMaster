# =============================================================================
# toolchain/msvc.cmake — resolve short MSVC tool names to absolute paths
# =============================================================================

## @brief Read the default MSVC toolset folder from a VS install.
## @param[out] out_var Parent-scope version string (e.g. `14.51.36231`),
##            empty if the marker file is missing.
## @param[in] vs_root Visual Studio installation path from vswhere
##            `-property installationPath`.
## @note Source of truth is
##       `VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt`.
##       That is the same folder vcvars / INCLUDE use. Globbing
##       `VC/Tools/MSVC/*` is **not** equivalent: CI images ship 14.29
##       and 14.51 side by side and the glob returns 14.29 first
##       (STL1001: cl 19.29 + headers 14.51).
function(_bm_tc_msvc_default_toolset out_var vs_root)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_msvc_default_toolset")
	set(_ver "")
	if(NOT vs_root STREQUAL "")
		set(_marker "${vs_root}/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt")
		if(EXISTS "${_marker}")
			file(READ "${_marker}" _ver)
			string(STRIP "${_ver}" _ver)
		endif()
	endif()
	set(${out_var} "${_ver}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG "MSVC default toolset at '${vs_root}' → '${_ver}'")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_msvc_default_toolset")
endfunction()

## @brief Latest VS install path that has the x86/x64 VC tools.
## @param[out] out_var Parent-scope path, empty if vswhere is missing
##            or returns nothing.
function(_bm_tc_msvc_vs_root out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_msvc_vs_root")
	set(_root "")
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
				-property installationPath
			OUTPUT_VARIABLE _root
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_QUIET
		)
		string(REPLACE "\\" "/" _root "${_root}")
		string(STRIP "${_root}" _root)
	endif()
	set(${out_var} "${_root}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_msvc_vs_root")
endfunction()

## @brief Resolve a short MSVC tool name to an absolute path when possible.
## @param[out] out_var Parent-scope variable receiving the path (or the short
##            name if resolution fails).
## @param[in] tool_name Tool basename without extension (`cl`, `lib`, `link`),
##            or an already-absolute path.
## @note Order:
##       1. Already-absolute existing path (caller knows what they want).
##       2. `<vs>/VC/Tools/MSVC/<default>/bin/Hostx64/x64/<tool>.exe`
##          where `<default>` is `Microsoft.VCToolsVersion.default.txt`.
##          `cl`, `lib` and `link` therefore share INCLUDE/LIB.
##       3. `find_program` — last, because PATH on GHA often has an
##          older toolset first (14.29 before 14.51).
## @note Required for the Ninja generator: `CMAKE_AR=lib` is otherwise
##       treated as a path relative to the build directory.
## @note Uses a unique cache variable per tool name so successive
##       resolves (`cl`, then `lib`, then `link`) do not reuse a stale
##       `find_program` result.
function(_bm_tc_resolve_msvc_tool out_var tool_name)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_resolve_msvc_tool")
	if(tool_name STREQUAL "")
		set(${out_var} "" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
		return()
	endif()

	if(IS_ABSOLUTE "${tool_name}" AND EXISTS "${tool_name}")
		_bm_path_normalize(_abs "${tool_name}")
		set(${out_var} "${_abs}" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
		return()
	endif()

	string(REGEX REPLACE "\\.exe$" "" _base "${tool_name}")

	_bm_tc_msvc_vs_root(_vs_root)
	_bm_tc_msvc_default_toolset(_ts "${_vs_root}")
	if(NOT _vs_root STREQUAL "" AND NOT _ts STREQUAL "")
		set(_candidate "${_vs_root}/VC/Tools/MSVC/${_ts}/bin/Hostx64/x64/${_base}.exe")
		if(EXISTS "${_candidate}")
			_bm_path_normalize(_candidate "${_candidate}")
			set(${out_var} "${_candidate}" PARENT_SCOPE)
			_bm_log_message(TOOLCHAIN DEBUG
				"MSVC ${_base} → ${_candidate} (default toolset ${_ts})")
			_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
			return()
		endif()
	endif()

	# Unique cache key per tool — shared _bm_found would stick on the first hit (e.g. cl).
	string(MAKE_C_IDENTIFIER "${tool_name}" _bm_tool_id)
	set(_bm_cache_var "_BM_MSVC_TOOL_${_bm_tool_id}")

	find_program(${_bm_cache_var} NAMES "${_base}" "${_base}.exe")
	if(${_bm_cache_var})
		_bm_path_normalize(_bm_found "${${_bm_cache_var}}")
		set(${out_var} "${_bm_found}" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN DEBUG
			"MSVC ${_base} → ${_bm_found} (find_program fallback)")
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
		return()
	endif()

	set(${out_var} "${tool_name}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
endfunction()
