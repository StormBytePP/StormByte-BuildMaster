# =============================================================================
# env/prefix_search.cmake — shared install prefix on flags + Windows INCLUDE/LIB
# =============================================================================

## @brief Append one compiler/linker token unless it is already present.
## @param[in,out] io_flags Name of the variable holding the flag string.
## @param[in] token Token to append (`-I…`, `-L…`, `/I…`, `/LIBPATH:…`).
## @note Empty @p token is a no-op. Writes the updated string to PARENT_SCOPE
##       under the same name.
function(_buildmaster_prefix_append_flag io_flags token)
	if("${token}" STREQUAL "")
		return()
	endif()
	set(_cur "${${io_flags}}")
	string(FIND "${_cur}" "${token}" _pos)
	if(NOT _pos EQUAL -1)
		return()
	endif()
	if(_cur STREQUAL "")
		set(${io_flags} "${token}" PARENT_SCOPE)
	else()
		set(${io_flags} "${_cur} ${token}" PARENT_SCOPE)
	endif()
endfunction()

## @brief Prepend a native directory to a Windows `INCLUDE` / `LIB` list.
## @param[in,out] io_list Name of the variable (`INCLUDE` or `LIB`).
## @param[in] dir Directory in CMake path form.
## @note `file(TO_NATIVE_PATH)` so `cl.exe` / `link.exe` accept the entry.
##       If the CMake variable is empty, seeds from `$ENV{INCLUDE}` / `$ENV{LIB}`
##       (vcvars) so the SDK paths are not wiped. Idempotent.
function(_buildmaster_prefix_prepend_win_env io_list dir)
	if("${dir}" STREQUAL "")
		return()
	endif()
	file(TO_NATIVE_PATH "${dir}" _nat)
	set(_cur "${${io_list}}")
	if(_cur STREQUAL "" AND DEFINED ENV{${io_list}} AND NOT "$ENV{${io_list}}" STREQUAL "")
		set(_cur "$ENV{${io_list}}")
	endif()
	if(NOT _cur STREQUAL "")
		string(FIND "${_cur}" "${_nat}" _pos)
		if(NOT _pos EQUAL -1)
			set(${io_list} "${_cur}" PARENT_SCOPE)
			return()
		endif()
		set(${io_list} "${_nat};${_cur}" PARENT_SCOPE)
	else()
		set(${io_list} "${_nat}" PARENT_SCOPE)
	endif()
endfunction()

## @brief Point compile/link search at the shared BuildMaster install prefix.
## @note 1.0.0 runners already prepended `@CFLAGS@` / `@CXXFLAGS@` / `@LDFLAGS@`
##       (Unix) and `@INCLUDE@` / `@LIB@` (Windows). Those placeholders were
##       never filled from `BUILDMASTER_INSTALL_*`. This function is that fill.
## @note Unix / MinGW: `-I${BUILDMASTER_INSTALL_INCLUDEDIR}` on `CFLAGS`,
##       `CXXFLAGS`, `CMAKE_C_FLAGS`, `CMAKE_CXX_FLAGS`; `-L${…LIBDIR}` on
##       `LDFLAGS`, `CMAKE_EXE_LINKER_FLAGS`, `CMAKE_SHARED_LINKER_FLAGS`,
##       `CMAKE_MODULE_LINKER_FLAGS`.
## @note Windows MSVC / clang-cl: `/I` and `/LIBPATH:` on the same flag
##       variables, **and** native paths prepended to `INCLUDE` and `LIB`
##       (`cl.exe` / `link.exe` honour the env vars even when CMake flags
##       are empty). Existing `ENV{INCLUDE}` / `ENV{LIB}` from vcvars stay
##       after the BuildMaster dirs.
## @note Idempotent. No-op when `BUILDMASTER_INSTALL_INCLUDEDIR` or
##       `BUILDMASTER_INSTALL_LIBDIR` is unset.
## @note Writes `CMAKE_C_FLAGS`, `CMAKE_CXX_FLAGS`, `CMAKE_EXE_LINKER_FLAGS`,
##       `CMAKE_SHARED_LINKER_FLAGS`, `CMAKE_MODULE_LINKER_FLAGS`, `CFLAGS`,
##       `CXXFLAGS`, `LDFLAGS`, `INCLUDE`, `LIB` to the parent scope.
function(buildmaster_apply_install_search_paths)
	_bm_log_message(ENV LOWLEVEL "Entering buildmaster_apply_install_search_paths")

	if(NOT DEFINED BUILDMASTER_INSTALL_INCLUDEDIR OR BUILDMASTER_INSTALL_INCLUDEDIR STREQUAL "")
		_bm_log_message(ENV LOWLEVEL "Exiting buildmaster_apply_install_search_paths (no INCLUDEDIR)")
		return()
	endif()
	if(NOT DEFINED BUILDMASTER_INSTALL_LIBDIR OR BUILDMASTER_INSTALL_LIBDIR STREQUAL "")
		_bm_log_message(ENV LOWLEVEL "Exiting buildmaster_apply_install_search_paths (no LIBDIR)")
		return()
	endif()

	normalize_cmake_path(_inc "${BUILDMASTER_INSTALL_INCLUDEDIR}")
	normalize_cmake_path(_lib "${BUILDMASTER_INSTALL_LIBDIR}")

	if(NOT DEFINED CMAKE_C_FLAGS)
		set(CMAKE_C_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_CXX_FLAGS)
		set(CMAKE_CXX_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_EXE_LINKER_FLAGS)
		set(CMAKE_EXE_LINKER_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_SHARED_LINKER_FLAGS)
		set(CMAKE_SHARED_LINKER_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_MODULE_LINKER_FLAGS)
		set(CMAKE_MODULE_LINKER_FLAGS "")
	endif()
	if(NOT DEFINED CFLAGS)
		set(CFLAGS "")
	endif()
	if(NOT DEFINED CXXFLAGS)
		set(CXXFLAGS "")
	endif()
	if(NOT DEFINED LDFLAGS)
		set(LDFLAGS "")
	endif()
	if(NOT DEFINED INCLUDE)
		set(INCLUDE "")
	endif()
	if(NOT DEFINED LIB)
		set(LIB "")
	endif()

	set(_msvc_like OFF)
	if(MSVC)
		set(_msvc_like ON)
	elseif(CMAKE_C_COMPILER MATCHES "clang-cl" OR CMAKE_CXX_COMPILER MATCHES "clang-cl")
		set(_msvc_like ON)
	endif()

	if(_msvc_like)
		set(_iflag "/I${_inc}")
		set(_lflag "/LIBPATH:${_lib}")
	else()
		set(_iflag "-I${_inc}")
		set(_lflag "-L${_lib}")
	endif()

	_buildmaster_prefix_append_flag(CMAKE_C_FLAGS "${_iflag}")
	_buildmaster_prefix_append_flag(CMAKE_CXX_FLAGS "${_iflag}")
	_buildmaster_prefix_append_flag(CFLAGS "${_iflag}")
	_buildmaster_prefix_append_flag(CXXFLAGS "${_iflag}")
	_buildmaster_prefix_append_flag(CMAKE_EXE_LINKER_FLAGS "${_lflag}")
	_buildmaster_prefix_append_flag(CMAKE_SHARED_LINKER_FLAGS "${_lflag}")
	_buildmaster_prefix_append_flag(CMAKE_MODULE_LINKER_FLAGS "${_lflag}")
	_buildmaster_prefix_append_flag(LDFLAGS "${_lflag}")

	if(WIN32)
		_buildmaster_prefix_prepend_win_env(INCLUDE "${_inc}")
		_buildmaster_prefix_prepend_win_env(LIB "${_lib}")
	endif()

	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}" PARENT_SCOPE)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}" PARENT_SCOPE)
	set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}" PARENT_SCOPE)
	set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}" PARENT_SCOPE)
	set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS}" PARENT_SCOPE)
	set(CFLAGS "${CFLAGS}" PARENT_SCOPE)
	set(CXXFLAGS "${CXXFLAGS}" PARENT_SCOPE)
	set(LDFLAGS "${LDFLAGS}" PARENT_SCOPE)
	set(INCLUDE "${INCLUDE}" PARENT_SCOPE)
	set(LIB "${LIB}" PARENT_SCOPE)

	_bm_log_message(ENV DEBUG
		"prefix search: inc=${_inc} lib=${_lib} msvc_like=${_msvc_like}")
	_bm_log_message(ENV LOWLEVEL "Exiting buildmaster_apply_install_search_paths")
endfunction()
