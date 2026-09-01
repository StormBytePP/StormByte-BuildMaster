# =============================================================================
# tools/meson/stages.cmake — _bm_tools_meson_stages
# =============================================================================

## @brief Append the shared install prefix to Meson link args.
## @param[in,out] _args_var Name of the string variable holding `_MESON_LINK_ARGS`.
## @note Runner already exports LIBRARY_PATH / LDFLAGS / LIB, and the native
##       file already lists the same `-L`/`/LIBPATH:` under `[built-in options]`.
##       That is not enough for nested Meson:
##         1. `meson setup -Dc_link_args=…` is command-line and **replaces**
##            native-file `c_link_args` / `cpp_link_args` (Meson precedence:
##            CLI > machine file > env). An empty or fuse-ld-only `-D`
##            therefore wipes the prefix that the .ini already had.
##         2. `cc.find_library()` / codec probes (mp3lame, gsm, …) use the
##            compiler's link line (`c_link_args`), not only `LIBRARY_PATH`.
##            Env search can still pick a system `.so` when both exist.
##         3. The final ninja link of ffmpeg does not reliably inherit the
##            runner's LIBRARY_PATH order; `-L` on `c_link_args` does.
##       So the prefix must live in `_MESON_LINK_ARGS` even though runner
##       and native already carry it. Duplicate tokens are skipped.
function(_bm_tools_meson_append_prefix_link_args _args_var)
	if(NOT DEFINED BUILDMASTER_INSTALL_DIR OR BUILDMASTER_INSTALL_DIR STREQUAL "")
		return()
	endif()
	if(NOT DEFINED CMAKE_INSTALL_LIBDIR OR CMAKE_INSTALL_LIBDIR STREQUAL "")
		set(_libdir "lib")
	else()
		set(_libdir "${CMAKE_INSTALL_LIBDIR}")
	endif()
	set(_prefix_lib "${BUILDMASTER_INSTALL_DIR}/${_libdir}")
	_bm_path_normalize(_prefix_lib "${_prefix_lib}")
	if(MSVC OR CMAKE_C_COMPILER MATCHES "clang-cl" OR CMAKE_CXX_COMPILER MATCHES "clang-cl")
		set(_tok "/LIBPATH:${_prefix_lib}")
	else()
		set(_tok "-L${_prefix_lib}")
	endif()
	set(_cur "${${_args_var}}")
	if(_cur MATCHES "(^| )${_tok}( |$)")
		return()
	endif()
	if(_cur STREQUAL "")
		set(${_args_var} "${_tok}" PARENT_SCOPE)
	else()
		set(${_args_var} "${_cur} ${_tok}" PARENT_SCOPE)
	endif()
endfunction()

## @brief Create setup/compile/install scripts for a Meson-built component.
## @param[out] _file_setup Name of the variable to set in parent scope
##            with the generated Meson `*_configure.cmake` script path.
## @param[out] _file_compile Name of the variable to set in parent scope
##            with the generated Meson `*_compile.cmake` script path.
## @param[out] _file_install Name of the variable to set in parent scope
##            with the generated Meson `*_install.cmake` script path.
## @param[in] _component Simple component name used to form stage names
##            and derive the file name.
## @param[in] _component_title Human-friendly component title.
## @param[in] _srcdir Path to the component source directory.
## @param[in] _builddir Path to the component build directory.
## @param[in] _meson_options List of Meson options to pass to the
##            component's setup.
## @param[in] _library_mode Either `static`, `shared`, or `headers`.
## @param[in] _output_libraries One or more full paths to the built
##            library/artifact(s) produced by the component; exported as
##            `_MESON_OUTPUT_LIBRARIES` for template use.
## @param[in] _indent_level Optional (ARGV10) tab count for eager setup
##            STATUS. Exported as `_MESON_INDENT_LEVEL` (digit) and
##            `_MESON_INDENT_` (tab characters) for `setup.cmake.in`.
##            Compile/install COMMENT stays at 0.
## @param[in] _toolchain Optional (ARGV11) BuildMaster toolchain name
##            (`gcc`, `clang`, `clang-cl`, `msvc`). Empty means inherit the
##            parent job toolchain. When set, compilers, linker, archiver and
##            component-local env runners apply only to this component's stages.
## @param[in] _configure_via_target Optional (ARGV12) `"1"` when setup runs
##            under the deferred `<id>_configure` custom target (suppress
##            hierarchical STATUS). `"0"` or empty otherwise.
## @note Reads `_BM_RENAME_ENABLED` from the caller (`"1"` / `"0"`). If unset,
##       defaults to `"1"`. The rename oficio is selected by
##       `BUILDMASTER_COMPONENT_<id>_INSTALL_OFICIOS` /
##       `_bm_install_rules_write`, not by an `if` in the wrapper.
## @note Reads `_BM_BUILDONLY` from the caller (`"1"` / `"0"`). If unset,
##       defaults to `"0"`. When `"1"`, `install_library.cmake.in` skips
##       `meson install` and still `include()`s the rules (RENAME /
##       outputs under BUILDDIR). Token name is unchanged.
## @note Reads `_BM_STRIPRES_ENABLED` from the caller (`"1"` / `"0"`). If
##       unset, defaults to `"1"`. The strip oficio is emitted only for
##       static + STRIPRES. Other archivers no-op inside the strip script.
## @note Reads `_BM_PC_ENABLED` and `_BM_PC_*` from the caller. If
##       `_BM_PC_ENABLED` is unset, defaults to `"0"`.
##       `_bm_install_rules_write` calls `_bm_component_pkgconfig_fill_vars`
##       before configuring `pc` so GLOBAL
##       `BUILDMASTER_COMPONENT_<id>_PC_*` are sealed. Empty `-DPC_NAME=`
##       is FATAL in `write_pc`.
## @note After sanitize, calls `_bm_install_rules_write` and sets
##       `_BM_INSTALL_RULES`. FATAL if that path is empty or missing.
##       Wrapper template is `install_library.cmake.in` →
##       `<safe>_install_library.cmake`. `install_exec.cmake.in` is gone.
## @note Always exports BM_COMPONENT_ENV_CMAKE_* (outer deferred -P uses
##       cmake) and BM_COMPONENT_ENV_MESON_* in the parent scope so library
##       fragments and stage scripts share the same runners.
## @note `_MESON_NATIVE_FILE` is the Meson `--native-file` for this component:
##       `TOOLCHAIN=` profile file, or this process's compiler family.
## @note Before writing templates, calls
##       `_bm_env_apply_install_search_paths()` so `_MESON_C_ARGS` /
##       `_MESON_CXX_ARGS` / `_MESON_LINK_ARGS` include the shared prefix
##       (`-I`/`-L` or `/I`/`/LIBPATH:`). Per-component runners also get
##       Windows `INCLUDE`/`LIB` when TOOLCHAIN= is set.
## @note After fuse-ld and the last `_bm_env_apply_install_search_paths()`,
##       `_bm_tools_meson_append_prefix_link_args(_MESON_LINK_ARGS)` puts
##       the prefix `-L`/`/LIBPATH:` on the CLI `-Dc_link_args` /
##       `-Dcpp_link_args` line. Required because those `-D` values
##       override `[built-in options]` in the native file (see helper).
## @note `MESON_BUILD_TYPE` is derived from `CMAKE_BUILD_TYPE` (`Debug` →
##       `debug`, `RelWithDebInfo` → `debugoptimized`, `MinSizeRel` →
##       `minsize`, `Release` or empty/multi-config → `release`). Meson
##       rejects an empty `-Dbuildtype=` (reports Value ".").
function(_bm_tools_meson_stages _file_setup _file_compile _file_install _component _component_title _srcdir _builddir _meson_options _library_mode _output_libraries)
	_bm_log_message(MESON LOWLEVEL "Entering _bm_tools_meson_stages")
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
	else()
		set(_indent_level 0)
	endif()
	if(NOT _indent_level MATCHES "^[0-9]+$")
		set(_indent_level 0)
	endif()
	set(_MESON_INDENT_LEVEL "${_indent_level}")
	if(_indent_level GREATER 0)
		string(REPEAT "\t" ${_indent_level} _MESON_INDENT_)
	else()
		set(_MESON_INDENT_ "")
	endif()

	if(ARGC GREATER 11)
		set(_toolchain_raw "${ARGV11}")
	else()
		set(_toolchain_raw "")
	endif()

	if(ARGC GREATER 12)
		set(_BM_CONFIGURE_VIA_TARGET "${ARGV12}")
	else()
		set(_BM_CONFIGURE_VIA_TARGET "0")
	endif()

	# _bm_graph_create / collect_outputs set these; raw callers get defaults
	if(NOT DEFINED _BM_RENAME_ENABLED)
		set(_BM_RENAME_ENABLED "1")
	endif()
	if(NOT DEFINED _BM_BUILDONLY)
		set(_BM_BUILDONLY "0")
	endif()
	if(NOT DEFINED _BM_STRIPRES_ENABLED)
		set(_BM_STRIPRES_ENABLED "1")
	endif()
	if(NOT DEFINED _BM_PC_ENABLED)
		set(_BM_PC_ENABLED "0")
	endif()
	if(NOT DEFINED _BM_PC_NAME)
		set(_BM_PC_NAME "")
	endif()
	if(NOT DEFINED _BM_PC_VERSION)
		set(_BM_PC_VERSION "")
	endif()
	if(NOT DEFINED _BM_PC_DESCRIPTION)
		set(_BM_PC_DESCRIPTION "")
	endif()
	if(NOT DEFINED _BM_PC_LIBS)
		set(_BM_PC_LIBS "")
	endif()
	if(NOT DEFINED _BM_PC_REQUIRES)
		set(_BM_PC_REQUIRES "")
	endif()
	if(NOT DEFINED _BM_PC_CFLAGS)
		set(_BM_PC_CFLAGS "")
	endif()
	if(NOT DEFINED _BM_PC_OUT)
		set(_BM_PC_OUT "")
	endif()

	_bm_tc_validate(_toolchain_name "${_toolchain_raw}")

	# Profile native file when TOOLCHAIN= is set; otherwise this process's
	# compiler family. Never keep the outer job default unless this process
	# still uses that family.
	if(COMMAND _bm_tc_get_meson_native_file)
		_bm_tc_get_meson_native_file(_MESON_NATIVE_FILE
			TOOLCHAIN "${_toolchain_name}")
	else()
		set(_MESON_NATIVE_FILE "")
	endif()

	if(NOT _toolchain_name STREQUAL "")
		set(_MESON_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain_name})")
		_bm_log_message(MESON DEBUG "_bm_tools_meson_stages(${_component}): TOOLCHAIN=${_toolchain_name}")
	else()
		set(_MESON_TOOLCHAIN_SUFFIX "")
	endif()

	if(${_library_mode} STREQUAL "static")
		set(_MESON_LIBRARY_TYPE "static")
		list(APPEND _meson_options "-Db_staticpic=true")
	elseif(${_library_mode} STREQUAL "shared")
		set(_MESON_LIBRARY_TYPE "shared")
	elseif(${_library_mode} STREQUAL "headers")
		set(_MESON_LIBRARY_TYPE "static")
		list(APPEND _meson_options "-Db_staticpic=true")
	elseif(${_library_mode} STREQUAL "executable")
		set(_MESON_LIBRARY_TYPE "static")
	else()
		_bm_log_message(MESON FATAL "Unknown mode '${_library_mode}' in _bm_tools_meson_stages (expected static, shared, headers, or executable)")
	endif()

	set(_MESON_COMPONENT "${_component}")
	set(_MESON_COMPONENT_TITLE "${_component_title}")
	set(_MESON_STAGE_BUILD "${_component}_build")
	set(_MESON_STAGE_INSTALL "${_component}_install")
	set(_MESON_BUILD_DIR "${_builddir}")
	set(_MESON_SRCDIR "${_srcdir}")
	set(_MESON_OUTPUT_LIBRARIES "${_output_libraries}")

	set(_bm_c_compiler "${CMAKE_C_COMPILER}")
	set(_bm_cxx_compiler "${CMAKE_CXX_COMPILER}")
	set(_bm_c_launcher "${CMAKE_C_COMPILER_LAUNCHER}")
	set(_bm_cxx_launcher "${CMAKE_CXX_COMPILER_LAUNCHER}")

	if(NOT DEFINED CMAKE_EXE_LINKER_FLAGS)
		set(CMAKE_EXE_LINKER_FLAGS "")
	endif()
	set(_MESON_LINK_ARGS "${CMAKE_EXE_LINKER_FLAGS}")

	if(NOT DEFINED CMAKE_C_FLAGS)
		set(CMAKE_C_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_CXX_FLAGS)
		set(CMAKE_CXX_FLAGS "")
	endif()

	set(_MESON_AR "")
	set(_MESON_RANLIB "")

	if(NOT DEFINED PATH)
		set(PATH "")
	endif()

	if(NOT _toolchain_name STREQUAL "")
		_bm_tc_load_profile("${_toolchain_name}")

		# Short tool names + bindirs on PATH (avoid paths with spaces via cmd)
		get_filename_component(_cmake_dir "${CMAKE_COMMAND}" DIRECTORY)
		get_filename_component(_cmake_name "${CMAKE_COMMAND}" NAME)
		_bm_path_normalize(_cmake_dir "${_cmake_dir}")
		if(MESON_EXECUTABLE)
			get_filename_component(_meson_dir "${MESON_EXECUTABLE}" DIRECTORY)
			get_filename_component(_meson_name "${MESON_EXECUTABLE}" NAME)
			_bm_path_normalize(_meson_dir "${_meson_dir}")
		else()
			set(_meson_dir "")
			set(_meson_name "meson")
		endif()
		set(_bm_path_prefix "${_cmake_dir}")
		if(NOT _meson_dir STREQUAL "")
			set(_bm_path_prefix "${_meson_dir};${_bm_path_prefix}")
		endif()
		if(PATH STREQUAL "")
			set(PATH "${_bm_path_prefix}")
		else()
			set(PATH "${_bm_path_prefix};${PATH}")
		endif()

		# Resolve short MSVC tool names before runners embed AR/CC into the env
		set(_bm_c_compiler "${BM_TC_C_COMPILER}")
		set(_bm_cxx_compiler "${BM_TC_CXX_COMPILER}")
		set(_MESON_AR "${BM_TC_AR}")
		set(_MESON_RANLIB "${BM_TC_RANLIB}")

		if(_toolchain_name STREQUAL "msvc" OR _toolchain_name STREQUAL "clang-cl")
			if(NOT _bm_c_compiler STREQUAL "" AND NOT IS_ABSOLUTE "${_bm_c_compiler}")
				_bm_tc_resolve_msvc_tool(_bm_c_compiler "${_bm_c_compiler}")
			endif()
			if(NOT _bm_cxx_compiler STREQUAL "" AND NOT IS_ABSOLUTE "${_bm_cxx_compiler}")
				_bm_tc_resolve_msvc_tool(_bm_cxx_compiler "${_bm_cxx_compiler}")
			endif()
			if(NOT _MESON_AR STREQUAL "" AND NOT IS_ABSOLUTE "${_MESON_AR}")
				_bm_tc_resolve_msvc_tool(_MESON_AR "${_MESON_AR}")
			endif()
			if(DEFINED BM_TC_LINKER AND NOT BM_TC_LINKER STREQUAL "" AND NOT IS_ABSOLUTE "${BM_TC_LINKER}")
				_bm_tc_resolve_msvc_tool(BM_TC_LINKER "${BM_TC_LINKER}")
			endif()
		endif()

		# BM_TC_* must match resolved values for the component runner bat/sh
		set(BM_TC_C_COMPILER "${_bm_c_compiler}")
		set(BM_TC_CXX_COMPILER "${_bm_cxx_compiler}")
		set(BM_TC_AR "${_MESON_AR}")
		if(NOT _MESON_RANLIB STREQUAL "")
			set(BM_TC_RANLIB "${_MESON_RANLIB}")
		endif()

		if(NOT _MESON_AR STREQUAL "")
			_bm_path_normalize(_MESON_AR "${_MESON_AR}")
		endif()
		if(NOT _MESON_RANLIB STREQUAL "")
			_bm_path_normalize(_MESON_RANLIB "${_MESON_RANLIB}")
		endif()

		_bm_tc_clean_ldflags(_MESON_LINK_ARGS
			"${_MESON_LINK_ARGS}" "${_toolchain_name}")
		_bm_tc_clean_cflags(CMAKE_C_FLAGS
			"${CMAKE_C_FLAGS}" "${_toolchain_name}")
		_bm_tc_clean_cflags(CMAKE_CXX_FLAGS
			"${CMAKE_CXX_FLAGS}" "${_toolchain_name}")

		if(COMMAND _bm_env_apply_install_search_paths)
			_bm_env_apply_install_search_paths()
		endif()

		# -fuse-ld= must be a driver flavor name, never an absolute path
		if(BM_TC_FORCE_LLD)
			_bm_tc_fuse_ld_flag(_bm_fuse_ld "LLD" "")
		elseif(_toolchain_name STREQUAL "msvc")
			_bm_tc_fuse_ld_flag(_bm_fuse_ld "MSVC" "")
		else()
			set(_bm_tc_lt "")
			if(DEFINED BM_TC_LINKER_TYPE)
				set(_bm_tc_lt "${BM_TC_LINKER_TYPE}")
			endif()
			set(_bm_tc_lnk "")
			if(DEFINED BM_TC_LINKER)
				set(_bm_tc_lnk "${BM_TC_LINKER}")
			endif()
			_bm_tc_fuse_ld_flag(_bm_fuse_ld "${_bm_tc_lt}" "${_bm_tc_lnk}")
		endif()
		if(NOT _bm_fuse_ld STREQUAL "")
			string(APPEND _MESON_LINK_ARGS " ${_bm_fuse_ld}")
		endif()

		_bm_env_create_runners(
			_bm_tc_runner
			_bm_tc_runner_silent
			"${_component}"
			"${_toolchain_name}"
		)

		set(ENV_MESON_COMMAND ${_bm_tc_runner} "${_meson_name}")
		set(ENV_MESON_SILENT_COMMAND ${_bm_tc_runner_silent} "${_meson_name}")
		if(BUILDMASTER_VERBOSE)
			set(ENV_MESON_COMPILE_COMMAND ${_bm_tc_runner} "${_meson_name}")
		else()
			set(ENV_MESON_COMPILE_COMMAND ${_bm_tc_runner_silent} "${_meson_name}")
		endif()

		set(ENV_CMAKE_COMMAND ${_bm_tc_runner} "${_cmake_name}")
		set(ENV_CMAKE_SILENT_COMMAND ${_bm_tc_runner_silent} "${_cmake_name}")
		if(BUILDMASTER_VERBOSE)
			set(ENV_CMAKE_COMPILE_COMMAND ${_bm_tc_runner} "${_cmake_name}")
		else()
			set(ENV_CMAKE_COMPILE_COMMAND ${_bm_tc_runner_silent} "${_cmake_name}")
		endif()
	else()
		# Inherit parent: strip MSVC LTCG tokens if parent is clang-cl
		if(CMAKE_C_COMPILER MATCHES "clang-cl" OR CMAKE_CXX_COMPILER MATCHES "clang-cl")
			_bm_tc_clean_ldflags(_MESON_LINK_ARGS
				"${_MESON_LINK_ARGS}" "clang-cl")
			_bm_tc_clean_cflags(CMAKE_C_FLAGS
				"${CMAKE_C_FLAGS}" "clang-cl")
			_bm_tc_clean_cflags(CMAKE_CXX_FLAGS
				"${CMAKE_CXX_FLAGS}" "clang-cl")
		endif()

		if(COMMAND _bm_env_apply_install_search_paths)
			_bm_env_apply_install_search_paths()
		endif()

		set(_bm_lt "")
		if(DEFINED CMAKE_LINKER_TYPE)
			set(_bm_lt "${CMAKE_LINKER_TYPE}")
		endif()
		set(_bm_lnk "")
		if(DEFINED CMAKE_LINKER)
			set(_bm_lnk "${CMAKE_LINKER}")
		endif()
		_bm_tc_fuse_ld_flag(_bm_fuse_ld "${_bm_lt}" "${_bm_lnk}")
		if(NOT _bm_fuse_ld STREQUAL "")
			string(APPEND _MESON_LINK_ARGS " ${_bm_fuse_ld}")
		endif()

		if(DEFINED CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
			_bm_path_normalize(_MESON_AR "${CMAKE_AR}")
		elseif(DEFINED ENV{AR} AND NOT "$ENV{AR}" STREQUAL "")
			_bm_path_normalize(_MESON_AR "$ENV{AR}")
		endif()
		if(DEFINED CMAKE_RANLIB AND NOT CMAKE_RANLIB STREQUAL "")
			_bm_path_normalize(_MESON_RANLIB "${CMAKE_RANLIB}")
		elseif(DEFINED ENV{RANLIB} AND NOT "$ENV{RANLIB}" STREQUAL "")
			_bm_path_normalize(_MESON_RANLIB "$ENV{RANLIB}")
		endif()
	endif()

	string(STRIP "${_MESON_LINK_ARGS}" _MESON_LINK_ARGS)

	if(COMMAND _bm_env_apply_install_search_paths)
		_bm_env_apply_install_search_paths()
	endif()

	# CLI -Dc_link_args replaces native-file c_link_args. Keep prefix -L
	# here so probes (mp3lame) and the ffmpeg ninja link prefer BM libs
	# over a same-named system .so even when the runner and .ini already
	# advertise the prefix.
	_bm_tools_meson_append_prefix_link_args(_MESON_LINK_ARGS)
	string(STRIP "${_MESON_LINK_ARGS}" _MESON_LINK_ARGS)

	_bm_env_quote_cmd_list(_MESON_CMD_PREFIX ${ENV_MESON_COMMAND})
	_bm_env_quote_cmd_list(_MESON_SILENT_CMD_PREFIX ${ENV_MESON_SILENT_COMMAND})
	_bm_env_quote_cmd_list(_MESON_COMPILE_CMD_PREFIX ${ENV_MESON_COMPILE_COMMAND})

	if(CMAKE_BUILD_TYPE STREQUAL "Release" AND CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
		set(LTO_ENABLED "true")
	else()
		set(LTO_ENABLED "false")
	endif()

	# Meson -Dbuildtype= must be a concrete choice. Empty CMAKE_BUILD_TYPE
	# (or multi-config generators) used to substitute nothing and Meson
	# reported Value "." is not one of the choices.
	if(CMAKE_BUILD_TYPE STREQUAL "Debug")
		set(MESON_BUILD_TYPE "debug")
	elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
		set(MESON_BUILD_TYPE "debugoptimized")
	elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
		set(MESON_BUILD_TYPE "minsize")
	else()
		set(MESON_BUILD_TYPE "release")
	endif()

	if(BUILDMASTER_VERBOSE)
		set(_MESON_COMPILE_VERBOSE_ARGS "-v")
	else()
		set(_MESON_COMPILE_VERBOSE_ARGS "")
	endif()

	_bm_list_join(_MESON_OPTIONS "${_meson_options}" " ")
	_bm_path_sanitize(_MESON_COMPONENT_SAFE "${_component}")

	set(_MESON_C_ARGS "${CMAKE_C_FLAGS}")
	set(_MESON_CXX_ARGS "${CMAKE_CXX_FLAGS}")

	# MSVC-like drivers: request CodeView (/Z7) for nested Meson objects.
	# Do not force /std:c*; upstream projects (e.g. PostgreSQL) set the C
	# standard themselves. Unconditional /std:c11 broke real MSVC builds.
	if(MSVC OR _toolchain_name STREQUAL "msvc" OR _toolchain_name STREQUAL "clang-cl"
			OR CMAKE_C_COMPILER MATCHES "clang-cl" OR CMAKE_CXX_COMPILER MATCHES "clang-cl")
		string(APPEND _MESON_C_ARGS " /Z7")
		string(APPEND _MESON_CXX_ARGS " /Z7")
	endif()

	if(NOT DEFINED CMAKE_C_COMPILER_LAUNCHER)
		set(CMAKE_C_COMPILER_LAUNCHER "")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER)
		set(CMAKE_CXX_COMPILER_LAUNCHER "")
	endif()
	if(NOT _bm_c_launcher AND DEFINED ENV{CMAKE_C_COMPILER_LAUNCHER}
			AND NOT "$ENV{CMAKE_C_COMPILER_LAUNCHER}" STREQUAL "")
		set(_bm_c_launcher "$ENV{CMAKE_C_COMPILER_LAUNCHER}")
	endif()
	if(NOT _bm_cxx_launcher AND DEFINED ENV{CMAKE_CXX_COMPILER_LAUNCHER}
			AND NOT "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}" STREQUAL "")
		set(_bm_cxx_launcher "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}")
	endif()
	if(NOT _bm_c_launcher)
		set(_bm_c_launcher "${CMAKE_C_COMPILER_LAUNCHER}")
	endif()
	if(NOT _bm_cxx_launcher)
		set(_bm_cxx_launcher "${CMAKE_CXX_COMPILER_LAUNCHER}")
	endif()

	if(NOT DEFINED CCACHE_DIR)
		if(DEFINED ENV{CCACHE_DIR} AND NOT "$ENV{CCACHE_DIR}" STREQUAL "")
			set(CCACHE_DIR "$ENV{CCACHE_DIR}")
		else()
			set(CCACHE_DIR "")
		endif()
	endif()
	if(NOT DEFINED SCCACHE_DIR)
		if(DEFINED ENV{SCCACHE_DIR} AND NOT "$ENV{SCCACHE_DIR}" STREQUAL "")
			set(SCCACHE_DIR "$ENV{SCCACHE_DIR}")
		else()
			set(SCCACHE_DIR "")
		endif()
	endif()
	if(NOT CCACHE_DIR STREQUAL "")
		file(TO_CMAKE_PATH "${CCACHE_DIR}" CCACHE_DIR)
	endif()
	if(NOT SCCACHE_DIR STREQUAL "")
		file(TO_CMAKE_PATH "${SCCACHE_DIR}" SCCACHE_DIR)
	endif()

	set(CMAKE_C_COMPILER "${_bm_c_compiler}")
	set(CMAKE_CXX_COMPILER "${_bm_cxx_compiler}")
	set(CMAKE_C_COMPILER_LAUNCHER "${_bm_c_launcher}")
	set(CMAKE_CXX_COMPILER_LAUNCHER "${_bm_cxx_launcher}")

	set(BM_COMPONENT_ENV_CMAKE_COMMAND ${ENV_CMAKE_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND ${ENV_CMAKE_SILENT_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND ${ENV_CMAKE_COMPILE_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_MESON_COMMAND ${ENV_MESON_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_MESON_SILENT_COMMAND ${ENV_MESON_SILENT_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_MESON_COMPILE_COMMAND ${ENV_MESON_COMPILE_COMMAND} PARENT_SCOPE)

	set(_MESON_GIT_POST_INSTALL_RESET "")
	if(COMMAND _bm_tools_git_marker)
		_bm_tools_git_marker(_MESON_GIT_POST_INSTALL_RESET "${_srcdir}")
	endif()

	_bm_install_rules_write(
		"${_component}"
		"MESON"
		"${_component_title}"
		"${_MESON_COMPONENT_SAFE}"
		"${_MESON_OUTPUT_LIBRARIES}"
		_BM_INSTALL_RULES)
	if("${_BM_INSTALL_RULES}" STREQUAL "" OR NOT EXISTS "${_BM_INSTALL_RULES}")
		_bm_log_message(MESON FATAL
			"_bm_tools_meson_stages('${_component}'): install rules missing")
	endif()

	set(_MESON_SETUP_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_configure.cmake"
	)
	set(_MESON_COMPILE_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_compile.cmake"
	)
	set(_MESON_INSTALL_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_install.cmake"
	)
	set(_MESON_COMPILE_EXEC_SCRIPT
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_compile_exec.cmake"
	)
	set(_MESON_INSTALL_LIBRARY_SCRIPT
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_install_library.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/templates/setup.cmake.in"
		"${_MESON_SETUP_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/templates/compile_exec.cmake.in"
		"${_MESON_COMPILE_EXEC_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/templates/install_library.cmake.in"
		"${_MESON_INSTALL_LIBRARY_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/templates/compile.cmake.in"
		"${_MESON_COMPILE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/templates/install.cmake.in"
		"${_MESON_INSTALL_FILE}"
		@ONLY
	)

	set(${_file_setup} "${_MESON_SETUP_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_MESON_COMPILE_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_MESON_INSTALL_FILE}" PARENT_SCOPE)
	_bm_log_message(MESON DEBUG "Wrote Meson stages for ${_component} native=${_MESON_NATIVE_FILE} buildtype=${MESON_BUILD_TYPE}")
	_bm_log_message(MESON LOWLEVEL "Exiting _bm_tools_meson_stages")
endfunction()
