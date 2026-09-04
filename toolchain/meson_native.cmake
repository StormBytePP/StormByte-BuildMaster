# =============================================================================
# toolchain/meson_native.cmake — Meson native files per toolchain profile
# =============================================================================
#
# Variables set (and exported into the toolchain dump):
#   BUILDMASTER_MESON_NATIVE_FILE           - parent / default job compilers
#   BUILDMASTER_MESON_NATIVE_FILE_<name>    - written for the parent profile
#     at init; other profiles on TOOLCHAIN= via ensure
# =============================================================================

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief Quote a filesystem path for a Meson native-file string list entry.
## @param[out] out_var Parent-scope variable receiving a single-quoted path.
## @param[in]  path    Path to quote (backslashes become `/`).
function(_bm_tc_meson_native_quote out_var path)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_meson_native_quote")
	string(REPLACE "\\" "/" path "${path}")
	string(REPLACE "'" "\\'" path "${path}")
	set(${out_var} "'${path}'" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_quote")
endfunction()

## @brief Build one Meson [binaries] assignment line.
## @param[out] out_var Parent-scope `c = ['sccache', 'cl']` or `c = ['cl']`.
## @param[in] name Binary key (`c`, `cpp`, `ar`, `ld`, …).
## @param[in] compiler Path or short name (empty → no line).
## @param[in] launcher Optional ccache/sccache; empty = none. Never used for ar/ld.
function(_bm_tc_meson_native_bin_line out_var name compiler launcher)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_meson_native_bin_line")
	if(compiler STREQUAL "")
		set(${out_var} "" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_bin_line")
		return()
	endif()
	_bm_tc_meson_native_quote(_comp "${compiler}")
	if(NOT launcher STREQUAL "")
		_bm_tc_meson_native_quote(_launch "${launcher}")
		set(${out_var} "${name} = [${_launch}, ${_comp}]" PARENT_SCOPE)
	else()
		set(${out_var} "${name} = [${_comp}]" PARENT_SCOPE)
	endif()
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_bin_line")
endfunction()

## @brief Resolve the active compiler launcher (ccache or sccache).
## @param[out] out_var Parent-scope; empty when no launcher is set.
function(_bm_tc_meson_native_resolve_launcher out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_meson_native_resolve_launcher")
	set(_l "")
	if(DEFINED CMAKE_C_COMPILER_LAUNCHER AND NOT CMAKE_C_COMPILER_LAUNCHER STREQUAL "")
		set(_l "${CMAKE_C_COMPILER_LAUNCHER}")
	elseif(DEFINED CMAKE_CXX_COMPILER_LAUNCHER AND NOT CMAKE_CXX_COMPILER_LAUNCHER STREQUAL "")
		set(_l "${CMAKE_CXX_COMPILER_LAUNCHER}")
	elseif(DEFINED ENV{CMAKE_C_COMPILER_LAUNCHER} AND NOT "$ENV{CMAKE_C_COMPILER_LAUNCHER}" STREQUAL "")
		set(_l "$ENV{CMAKE_C_COMPILER_LAUNCHER}")
	elseif(DEFINED ENV{CMAKE_CXX_COMPILER_LAUNCHER} AND NOT "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}" STREQUAL "")
		set(_l "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}")
	endif()
	set(${out_var} "${_l}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_resolve_launcher")
endfunction()

## @brief Meson [built-in options] lines for the shared BM prefix.
## @param[out] out_block Parent-scope text (may be empty).
## @param[in]  profile_key `default` / `gcc` / `clang` / `clang-cl` / `msvc`.
function(_bm_tc_meson_native_prefix_options out_block profile_key)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_meson_native_prefix_options")
	if(NOT DEFINED BUILDMASTER_INSTALL_DIR OR BUILDMASTER_INSTALL_DIR STREQUAL "")
		set(${out_block} "" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_prefix_options")
		return()
	endif()

	set(_inc "${BUILDMASTER_INSTALL_DIR}")
	if(DEFINED CMAKE_INSTALL_INCLUDEDIR AND NOT CMAKE_INSTALL_INCLUDEDIR STREQUAL "")
		string(APPEND _inc "/${CMAKE_INSTALL_INCLUDEDIR}")
	else()
		string(APPEND _inc "/include")
	endif()
	set(_lib "${BUILDMASTER_INSTALL_DIR}")
	if(DEFINED CMAKE_INSTALL_LIBDIR AND NOT CMAKE_INSTALL_LIBDIR STREQUAL "")
		string(APPEND _lib "/${CMAKE_INSTALL_LIBDIR}")
	else()
		string(APPEND _lib "/lib")
	endif()
	_bm_path_normalize(_inc "${_inc}")
	_bm_path_normalize(_lib "${_lib}")

	string(TOLOWER "${profile_key}" _pk)
	if(_pk STREQUAL "msvc" OR _pk STREQUAL "clang-cl")
		set(_i_flag "/I${_inc}")
		set(_l_flag "/LIBPATH:${_lib}")
	else()
		set(_i_flag "-I${_inc}")
		set(_l_flag "-L${_lib}")
	endif()
	_bm_tc_meson_native_quote(_i_q "${_i_flag}")
	_bm_tc_meson_native_quote(_l_q "${_l_flag}")

	set(_block "[built-in options]\n")
	string(APPEND _block "c_args = [${_i_q}]\n")
	string(APPEND _block "cpp_args = [${_i_q}]\n")
	string(APPEND _block "c_link_args = [${_l_q}]\n")
	string(APPEND _block "cpp_link_args = [${_l_q}]\n")
	set(${out_block} "${_block}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG
		"Meson native prefix options (${profile_key}): ${_i_flag} ${_l_flag}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_prefix_options")
endfunction()

## @brief Archiver path for a Meson native file.
## @param[in]  profile_key `default` or a known profile name.
## @param[out] out_ar      Parent-scope path; empty if none.
function(_bm_tc_meson_native_ar profile_key out_ar)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_meson_native_ar")
	set(_ar "")
	string(TOLOWER "${profile_key}" _pk)
	if(_pk STREQUAL "" OR _pk STREQUAL "default")
		if(CMAKE_AR AND NOT CMAKE_AR STREQUAL "" AND EXISTS "${CMAKE_AR}")
			set(_ar "${CMAKE_AR}")
		endif()
	elseif(COMMAND _bm_tc_archiver_resolve)
		_bm_tc_archiver_resolve("${_pk}" _ar _style)
		unset(_style)
	endif()
	set(${out_ar} "${_ar}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG "Meson native ar (${profile_key}) → ${_ar}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_ar")
endfunction()

## @brief Linker path for a Meson native file (`[binaries] ld`).
## @param[in]  profile_key `default` or a known profile name.
## @param[out] out_ld      Parent-scope path; empty if the profile has no linker.
## @note `gcc` leaves BM_TC_LINKER empty (bfd via the driver). `msvc` /
##       `clang-cl` link through `cl`/`clang-cl`; `ld` is still written
##       when BM_TC_LINKER is set so the file documents link.exe / lld-link.
function(_bm_tc_meson_native_ld profile_key out_ld)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_meson_native_ld")
	set(_ld "")
	string(TOLOWER "${profile_key}" _pk)
	if(_pk STREQUAL "" OR _pk STREQUAL "default")
		if(CMAKE_LINKER AND NOT CMAKE_LINKER STREQUAL "" AND EXISTS "${CMAKE_LINKER}")
			set(_ld "${CMAKE_LINKER}")
		endif()
	else()
		_bm_tc_load_profile("${_pk}")
		if(NOT BM_TC_LINKER STREQUAL "")
			if(_pk STREQUAL "msvc")
				_bm_tc_resolve_msvc_tool(_ld "${BM_TC_LINKER}")
			elseif(IS_ABSOLUTE "${BM_TC_LINKER}" AND EXISTS "${BM_TC_LINKER}")
				set(_ld "${BM_TC_LINKER}")
			else()
				find_program(_bm_tc_ld NAMES "${BM_TC_LINKER}" "${BM_TC_LINKER}.exe")
				if(_bm_tc_ld)
					_bm_path_normalize(_ld "${_bm_tc_ld}")
				else()
					_bm_log_message(TOOLCHAIN FATAL
						"toolchain profile '${_pk}': linker '${BM_TC_LINKER}' not found")
				endif()
				unset(_bm_tc_ld CACHE)
			endif()
		endif()
	endif()
	set(${out_ld} "${_ld}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG "Meson native ld (${profile_key}) → ${_ld}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_meson_native_ld")
endfunction()

## @brief Write (or overwrite) one Meson native file for a profile key.
## @param[in] profile_key `default` or a known toolchain name (`msvc`, …).
## @param[in] c_compiler C compiler path or short name.
## @param[in] cxx_compiler C++ compiler path or short name (falls back to C).
## @param[in] ARGN Optional `LAUNCHER <name-or-path>` override.
## @note `[binaries] ar` / `ld` come from the profile. Launcher is only on c/cpp.
function(_bm_tc_write_meson_native_file profile_key c_compiler cxx_compiler)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_write_meson_native_file")
	cmake_parse_arguments(ARG "" "LAUNCHER" "" ${ARGN})

	if(NOT DEFINED BUILDMASTER_SCRIPTSDIR OR BUILDMASTER_SCRIPTSDIR STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL
			"BUILDMASTER_SCRIPTSDIR is required to write Meson native files")
	endif()

	set(_dir "${BUILDMASTER_SCRIPTSDIR}/meson")
	file(MAKE_DIRECTORY "${_dir}")

	string(STRIP "${profile_key}" _key)
	string(TOLOWER "${_key}" _key)
	if(_key STREQUAL "" OR _key STREQUAL "default")
		set(_filename "native_default.ini")
		set(_var "BUILDMASTER_MESON_NATIVE_FILE")
		set(_label "default")
	else()
		set(_filename "native_${_key}.ini")
		set(_var "BUILDMASTER_MESON_NATIVE_FILE_${_key}")
		set(_label "${_key}")
	endif()

	set(_path "${_dir}/${_filename}")
	_bm_path_normalize(_path "${_path}")

	set(_launcher "")
	if(DEFINED ARG_LAUNCHER)
		set(_launcher "${ARG_LAUNCHER}")
	else()
		_bm_tc_meson_native_resolve_launcher(_launcher)
	endif()

	if(cxx_compiler STREQUAL "")
		set(cxx_compiler "${c_compiler}")
	endif()
	if(c_compiler STREQUAL "")
		set(c_compiler "${cxx_compiler}")
	endif()

	_bm_tc_meson_native_bin_line(_line_c   "c"   "${c_compiler}"   "${_launcher}")
	_bm_tc_meson_native_bin_line(_line_cpp "cpp" "${cxx_compiler}" "${_launcher}")
	_bm_tc_meson_native_ar("${_label}" _ar)
	_bm_tc_meson_native_bin_line(_line_ar "ar" "${_ar}" "")
	_bm_tc_meson_native_ld("${_label}" _ld)
	_bm_tc_meson_native_bin_line(_line_ld "ld" "${_ld}" "")
	_bm_tc_meson_native_prefix_options(_prefix_block "${_label}")

	set(_content "# Auto-generated by StormByte-BuildMaster (toolchain) — do not edit\n")
	string(APPEND _content "# profile: ${_label}\n")
	string(APPEND _content "[binaries]\n")
	if(NOT _line_c STREQUAL "")
		string(APPEND _content "${_line_c}\n")
	endif()
	if(NOT _line_cpp STREQUAL "")
		string(APPEND _content "${_line_cpp}\n")
	endif()
	if(NOT _line_ar STREQUAL "")
		string(APPEND _content "${_line_ar}\n")
	endif()
	if(NOT _line_ld STREQUAL "")
		string(APPEND _content "${_line_ld}\n")
	endif()
	if(NOT _prefix_block STREQUAL "")
		string(APPEND _content "\n${_prefix_block}")
	endif()

	file(WRITE "${_path}" "${_content}")

	set(${_var} "${_path}" PARENT_SCOPE)
	_bm_tc_export("${_var}" "${_path}")

	_bm_log_message(TOOLCHAIN DEBUG "Meson native file (${_label}) → ${_path}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_write_meson_native_file")
endfunction()

## @brief Materialize native_<profile>.ini from the loaded profile compilers.
## @param[in] profile_key Known toolchain name (`msvc`, `clang-cl`, …).
## @note demand_profile is a once-flag. It does not export BM_TC_* into
##       this scope on a second call. Always load_profile after demand.
function(_bm_tc_ensure_meson_native_profile profile_key)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_ensure_meson_native_profile")
	string(TOLOWER "${profile_key}" _prof)
	if(_prof STREQUAL "" OR _prof STREQUAL "default")
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_ensure_meson_native_profile")
		return()
	endif()
	if(DEFINED BUILDMASTER_MESON_NATIVE_FILE_${_prof}
			AND NOT BUILDMASTER_MESON_NATIVE_FILE_${_prof} STREQUAL ""
			AND EXISTS "${BUILDMASTER_MESON_NATIVE_FILE_${_prof}}")
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_ensure_meson_native_profile")
		return()
	endif()

	if(COMMAND _bm_tc_demand_profile)
		_bm_tc_demand_profile("${_prof}" "meson-native")
	endif()
	_bm_tc_load_profile("${_prof}" "meson-native")

	set(_pc "${BM_TC_C_COMPILER}")
	set(_px "${BM_TC_CXX_COMPILER}")
	if(_px STREQUAL "")
		set(_px "${_pc}")
	endif()
	if(_prof STREQUAL "msvc" OR _prof STREQUAL "clang-cl")
		if(COMMAND _bm_tc_resolve_msvc_tool)
			_bm_tc_resolve_msvc_tool(_pc_res "${_pc}")
			_bm_tc_resolve_msvc_tool(_px_res "${_px}")
			set(_pc "${_pc_res}")
			set(_px "${_px_res}")
		endif()
	else()
		if(NOT IS_ABSOLUTE "${_pc}")
			find_program(_bm_nc NAMES "${_pc}" "${_pc}.exe")
			if(_bm_nc)
				_bm_path_normalize(_pc "${_bm_nc}")
			endif()
			unset(_bm_nc CACHE)
		endif()
		if(NOT IS_ABSOLUTE "${_px}")
			find_program(_bm_nx NAMES "${_px}" "${_px}.exe")
			if(_bm_nx)
				_bm_path_normalize(_px "${_bm_nx}")
			endif()
			unset(_bm_nx CACHE)
		endif()
	endif()

	if(_pc STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL
			"Cannot write Meson native file for TOOLCHAIN='${_prof}': C compiler is empty after loading the profile.")
	endif()

	_bm_tc_meson_native_resolve_launcher(_launch)
	_bm_tc_write_meson_native_file("${_prof}" "${_pc}" "${_px}" LAUNCHER "${_launch}")
	set(BUILDMASTER_MESON_NATIVE_FILE_${_prof}
		"${BUILDMASTER_MESON_NATIVE_FILE_${_prof}}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_ensure_meson_native_profile")
endfunction()

## @brief Resolve which native-file path a Meson component should use.
## @param[out] out_var Parent-scope path (may be empty only when no TOOLCHAIN=).
## @param[in] ARGN Optional `TOOLCHAIN <name>`.
## @note Explicit TOOLCHAIN= never falls back to native_default.ini. Meson
##       prefers --native-file over CC/CXX; a parent default would compile
##       the leaf with the parent compiler (clang-cl vs msvc).
function(_bm_tc_get_meson_native_file out_var)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_get_meson_native_file")
	cmake_parse_arguments(ARG "" "TOOLCHAIN" "" ${ARGN})
	set(_path "")
	set(_key "")
	set(_explicit FALSE)

	if(DEFINED ARG_TOOLCHAIN AND NOT ARG_TOOLCHAIN STREQUAL "")
		string(TOLOWER "${ARG_TOOLCHAIN}" _key)
		set(_explicit TRUE)
	else()
		if(WIN32)
			if(CMAKE_C_COMPILER MATCHES "clang-cl" OR
				(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND
					CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC"))
				set(_key "clang-cl")
			elseif(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
				set(_key "msvc")
			endif()
		else()
			if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
				set(_key "gcc")
			elseif(CMAKE_C_COMPILER_ID STREQUAL "Clang")
				set(_key "clang")
			endif()
		endif()
	endif()

	if(NOT _key STREQUAL "")
		_bm_tc_ensure_meson_native_profile("${_key}")
		if(DEFINED BUILDMASTER_MESON_NATIVE_FILE_${_key}
				AND NOT BUILDMASTER_MESON_NATIVE_FILE_${_key} STREQUAL "")
			set(_path "${BUILDMASTER_MESON_NATIVE_FILE_${_key}}")
		endif()
	endif()

	if(_path STREQUAL "")
		if(_explicit)
			_bm_log_message(TOOLCHAIN FATAL
				"Meson native file for TOOLCHAIN='${_key}' is missing. Refusing native_default.ini (parent compilers). Write native_${_key}.ini or drop TOOLCHAIN= on that id.")
		elseif(DEFINED BUILDMASTER_MESON_NATIVE_FILE)
			set(_path "${BUILDMASTER_MESON_NATIVE_FILE}")
		endif()
	endif()
	set(${out_var} "${_path}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG "Meson native file for key '${_key}' explicit=${_explicit} → ${_path}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_get_meson_native_file")
endfunction()

## @brief Generate native_default.ini and native_<parent>.ini.
## @note Parent file uses CMAKE_C{XX}_COMPILER. Other profiles are
##       written only when a leaf sets TOOLCHAIN=.
function(_bm_tc_init_meson_native_files)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_init_meson_native_files")
	if(NOT DEFINED BUILDMASTER_SCRIPTSDIR OR BUILDMASTER_SCRIPTSDIR STREQUAL "")
		_bm_log_message(TOOLCHAIN DEBUG "Skipping Meson native files (BUILDMASTER_SCRIPTSDIR unset)")
		_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_init_meson_native_files")
		return()
	endif()

	_bm_tc_meson_native_resolve_launcher(_launch)

	set(_c "${CMAKE_C_COMPILER}")
	set(_cxx "${CMAKE_CXX_COMPILER}")
	if(_c STREQUAL "" AND NOT _cxx STREQUAL "")
		set(_c "${_cxx}")
	endif()
	if(_cxx STREQUAL "" AND NOT _c STREQUAL "")
		set(_cxx "${_c}")
	endif()

	if(_c STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL
			"Cannot write Meson native files: CMAKE_C_COMPILER and CMAKE_CXX_COMPILER are empty.")
	endif()

	_bm_tc_write_meson_native_file("default" "${_c}" "${_cxx}" LAUNCHER "${_launch}")
	set(BUILDMASTER_MESON_NATIVE_FILE "${BUILDMASTER_MESON_NATIVE_FILE}" PARENT_SCOPE)

	set(_parent "")
	if(COMMAND _bm_tc_infer_profile)
		_bm_tc_infer_profile(_parent)
	endif()
	if(_parent STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL
			"Cannot infer the parent toolchain profile from CMAKE_C_COMPILER='${CMAKE_C_COMPILER}'.")
	endif()

	_bm_tc_write_meson_native_file("${_parent}" "${_c}" "${_cxx}" LAUNCHER "${_launch}")
	if(DEFINED BUILDMASTER_MESON_NATIVE_FILE_${_parent})
		set(BUILDMASTER_MESON_NATIVE_FILE_${_parent}
			"${BUILDMASTER_MESON_NATIVE_FILE_${_parent}}" PARENT_SCOPE)
	endif()

	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_init_meson_native_files")
endfunction()
