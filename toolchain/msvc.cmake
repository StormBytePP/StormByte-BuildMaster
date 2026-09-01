# =============================================================================
# toolchain/msvc.cmake — resolve short MSVC tool names to absolute paths
# =============================================================================

## @brief True if @p path is an LLVM stand-in for an MSVC tool.
## @param[in]  path    Tool path or basename.
## @param[out] out_var Parent-scope TRUE / FALSE.
## @note `clang-cl`, `llvm-lib`, `lld-link`. TOOLCHAIN=clang-cl does not
##       call this; only TOOLCHAIN=msvc must refuse these names.
function(_bm_tc_msvc_is_llvm_tool path out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_msvc_is_llvm_tool")
	set(_hit FALSE)
	if(NOT path STREQUAL "")
		get_filename_component(_bn "${path}" NAME)
		string(TOLOWER "${_bn}" _bn)
		if(_bn STREQUAL "clang-cl" OR _bn STREQUAL "clang-cl.exe"
				OR _bn STREQUAL "llvm-lib" OR _bn STREQUAL "llvm-lib.exe"
				OR _bn STREQUAL "lld-link" OR _bn STREQUAL "lld-link.exe")
			set(_hit TRUE)
		endif()
	endif()
	set(${out_var} "${_hit}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_msvc_is_llvm_tool")
endfunction()

## @brief Resolve a short MSVC tool name to an absolute path when possible.
## @param[out] out_var Parent-scope variable receiving the path (or the short
##            name if resolution fails).
## @param[in] tool_name Tool basename without extension (`cl`, `lib`, `link`),
##            or an already-absolute path.
## @note Visual Studio `vswhere` (`Hostx64/x64`) first, then `find_program`.
##       An incoming absolute LLVM tool is ignored so a clang-cl parent
##       cannot pin `cl`/`lib`/`link`.
## @note Required for the Ninja generator: `CMAKE_AR=lib` is otherwise
##       treated as a path relative to the build directory.
## @note Uses a unique cache variable per tool name so successive resolves
##       (`cl`, then `lib`, then `link`) do not reuse a stale `find_program`
##       result.
function(_bm_tc_resolve_msvc_tool out_var tool_name)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_resolve_msvc_tool")
	if(tool_name STREQUAL "")
		set(${out_var} "" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
		return()
	endif()

	if(IS_ABSOLUTE "${tool_name}" AND EXISTS "${tool_name}")
		_bm_tc_msvc_is_llvm_tool("${tool_name}" _llvm)
		if(NOT _llvm)
			_bm_path_normalize(_abs "${tool_name}")
			set(${out_var} "${_abs}" PARENT_SCOPE)
			_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
			return()
		endif()
	endif()

	set(_vswhere "")
	if(DEFINED ENV{ProgramFiles\(x86\)})
		set(_vswhere "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")
	endif()
	if(NOT EXISTS "${_vswhere}" AND DEFINED ENV{ProgramFiles})
		set(_vswhere "$ENV{ProgramFiles}/Microsoft Visual Studio/Installer/vswhere.exe")
	endif()

	if(EXISTS "${_vswhere}")
		get_filename_component(_bm_want "${tool_name}" NAME_WE)
		execute_process(
			COMMAND "${_vswhere}"
				-latest
				-products *
				-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
				-find "VC/Tools/MSVC/*/bin/Hostx64/x64/${_bm_want}.exe"
			OUTPUT_VARIABLE _bm_found
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_QUIET
		)
		if(_bm_found)
			string(REPLACE "\r\n" "\n" _bm_found "${_bm_found}")
			string(REPLACE "\n" ";" _bm_found_list "${_bm_found}")
			foreach(_cand IN LISTS _bm_found_list)
				string(STRIP "${_cand}" _cand)
				if(_cand STREQUAL "" OR NOT EXISTS "${_cand}")
					continue()
				endif()
				_bm_tc_msvc_is_llvm_tool("${_cand}" _llvm)
				if(_llvm)
					continue()
				endif()
				_bm_path_normalize(_cand "${_cand}")
				set(${out_var} "${_cand}" PARENT_SCOPE)
				_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
				return()
			endforeach()
		endif()
	endif()

	string(MAKE_C_IDENTIFIER "${tool_name}" _bm_tool_id)
	set(_bm_cache_var "_BM_MSVC_TOOL_${_bm_tool_id}")
	unset(${_bm_cache_var} CACHE)
	find_program(${_bm_cache_var} NAMES "${tool_name}" "${tool_name}.exe")
	if(${_bm_cache_var})
		_bm_path_normalize(_bm_found "${${_bm_cache_var}}")
		_bm_tc_msvc_is_llvm_tool("${_bm_found}" _llvm)
		if(NOT _llvm)
			set(${out_var} "${_bm_found}" PARENT_SCOPE)
			_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
			return()
		endif()
	endif()

	set(${out_var} "${tool_name}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_resolve_msvc_tool")
endfunction()
