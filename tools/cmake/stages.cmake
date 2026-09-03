# =============================================================================
# tools/cmake/stages.cmake — _bm_tools_cmake_stages
# =============================================================================

## @brief Create configure/build/install scripts for a third-party component.
## @param[out] _file_configure Name of the variable to set in parent scope
##            with the path to the generated `configure_*.cmake` script.
## @param[out] _file_compile Name of the variable to set in parent scope
##            with the path to the generated `build_*.cmake` script.
## @param[out] _file_install Name of the variable to set in parent scope
##            with the path to the generated `install_*.cmake` script.
## @param[in] _component Short component identifier used to form stage
##            names and derive the file name.
## @param[in] _component_title Human-friendly component title.
## @param[in] _srcdir Path to the component source directory.
## @param[in] _builddir Path to the component build directory.
## @param[in] _options List of CMake options to pass to the component's
##            configure step.
## @param[in] _library_mode Either `static`, `shared`, or `headers`.
## @param[in] _output_libraries One or more full paths to the built
##            library/artifact(s) produced by the component; exported as
##            `_CMAKE_OUTPUT_LIBRARIES` for template use.
## @param[in] _indent_level Optional (ARGV10) tab count for eager configure
##            STATUS. Exported as `_CMAKE_INDENT_LEVEL` (digit) and
##            `_CMAKE_INDENT_` (tab characters) for `configure.cmake.in`.
##            Compile/install COMMENT stays at 0.
## @param[in] _toolchain Optional (ARGV11) BuildMaster toolchain name
##            (`gcc`, `clang`, `clang-cl`, `msvc`). Empty means inherit the
##            parent job toolchain. When set, _bm_tc_write_component
##            dumps the parent registry and appends this profile's compilers
##            and binutils (unified install tree).
## @param[in] _configure_via_target Optional (ARGV12) `"1"` when configure
##            runs under the deferred `<id>_configure` custom target
##            (suppress hierarchical STATUS; the target COMMENT is enough).
##            `"0"` or empty otherwise.
## @note C/CXX/LD flags go through `_bm_tc_translate_component`
##       (profile = TOOLCHAIN= or inferred parent; IPO mode from
##       `BUILDMASTER_COMPONENT_<id>_OPTSTR` via `_bm_opt_parse_ipo`).
##       EXE, SHARED and MODULE linker strings are translated separately.
##       After translate, `BM_TC_IPO_ON` / `BM_TC_IPO_COMPILE_OPTIONS` /
##       `BM_TC_LINK_GROUP_{START,END}` are sealed for
##       `configure.cmake.in`. The leaf keeps
##       `CMAKE_INTERPROCEDURAL_OPTIMIZATION` (recursive detect). Fat is
##       `CMAKE_<LANG>_COMPILE_OPTIONS_IPO`, not a second `-flto` on
##       `CMAKE_C_FLAGS`. GNU rescan (`--start-group`) only on Linux
##       gcc/clang `LINK_EXECUTABLE`. Darwin / msvc / clang-cl: empty.
## @note Reads `_BM_RENAME_ENABLED` from the caller (`"1"` / `"0"`). If unset,
##       defaults to `"1"`. The rename oficio is selected by
##       `BUILDMASTER_COMPONENT_<id>_INSTALL_OFICIOS` /
##       `_bm_install_rules_write`, not by an `if` in the wrapper.
## @note Reads `_BM_BUILDONLY` from the caller (`"1"` / `"0"`). If unset,
##       defaults to `"0"`. When `"1"`, `install_library.cmake.in` skips
##       `cmake --install` and still `include()`s the rules (RENAME /
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
## @note Always exports BM_COMPONENT_ENV_CMAKE_COMMAND,
##       BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND and
##       BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND in the parent scope so
##       component library fragments (eager and deferred `<id>_configure`)
##       use the same runners as the generated stage scripts.
## @note Before writing templates, calls
##       `_bm_env_apply_install_search_paths()` so nested
##       `-DCMAKE_C_FLAGS=` / linker flags include the shared prefix
##       (`-I`/`-L` or `/I`/`/LIBPATH:`, plus Windows `INCLUDE`/`LIB`
##       on per-component runners).
function(_bm_tools_cmake_stages _file_configure _file_compile _file_install _component _component_title _srcdir _builddir _options _library_mode _output_libraries)
	_bm_log_message(CMAKE LOWLEVEL "Entering _bm_tools_cmake_stages")
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
	else()
		set(_indent_level 0)
	endif()
	if(NOT _indent_level MATCHES "^[0-9]+$")
		set(_indent_level 0)
	endif()
	set(_CMAKE_INDENT_LEVEL "${_indent_level}")
	if(_indent_level GREATER 0)
		string(REPEAT "\t" ${_indent_level} _CMAKE_INDENT_)
	else()
		set(_CMAKE_INDENT_ "")
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

	if(NOT _toolchain_name STREQUAL "")
		set(_CMAKE_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain_name})")
	else()
		set(_CMAKE_TOOLCHAIN_SUFFIX "")
	endif()

	if(NOT CMAKE_C_COMPILER_LAUNCHER AND DEFINED ENV{CMAKE_C_COMPILER_LAUNCHER}
			AND NOT "$ENV{CMAKE_C_COMPILER_LAUNCHER}" STREQUAL "")
		set(CMAKE_C_COMPILER_LAUNCHER "$ENV{CMAKE_C_COMPILER_LAUNCHER}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_LAUNCHER AND DEFINED ENV{CMAKE_CXX_COMPILER_LAUNCHER}
			AND NOT "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}" STREQUAL "")
		set(CMAKE_CXX_COMPILER_LAUNCHER "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}")
	endif()
	if(NOT DEFINED CMAKE_C_COMPILER_LAUNCHER)
		set(CMAKE_C_COMPILER_LAUNCHER "")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER)
		set(CMAKE_CXX_COMPILER_LAUNCHER "")
	endif()

	if(NOT DEFINED CMAKE_LINKER_TYPE)
		set(CMAKE_LINKER_TYPE "")
	endif()
	if(NOT DEFINED CMAKE_LINKER)
		set(CMAKE_LINKER "")
	endif()
	if(NOT DEFINED CMAKE_C_COMPILER_LINKER)
		set(CMAKE_C_COMPILER_LINKER "${CMAKE_LINKER}")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_LINKER)
		set(CMAKE_CXX_COMPILER_LINKER "${CMAKE_LINKER}")
	endif()
	if(NOT DEFINED CMAKE_MT)
		set(CMAKE_MT "")
	endif()
	if(NOT DEFINED CMAKE_MODULE_LINKER_FLAGS)
		set(CMAKE_MODULE_LINKER_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_EXE_LINKER_FLAGS)
		set(CMAKE_EXE_LINKER_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_SHARED_LINKER_FLAGS)
		set(CMAKE_SHARED_LINKER_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
		set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE "")
	endif()

	if(NOT DEFINED CMAKE_AR)
		set(CMAKE_AR "")
	endif()
	if(NOT DEFINED CMAKE_C_COMPILER_AR)
		set(CMAKE_C_COMPILER_AR "${CMAKE_AR}")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_AR)
		set(CMAKE_CXX_COMPILER_AR "${CMAKE_AR}")
	endif()
	if(NOT DEFINED CMAKE_RANLIB)
		set(CMAKE_RANLIB "")
	endif()
	if(NOT DEFINED CMAKE_C_COMPILER_RANLIB)
		set(CMAKE_C_COMPILER_RANLIB "${CMAKE_RANLIB}")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_RANLIB)
		set(CMAKE_CXX_COMPILER_RANLIB "${CMAKE_RANLIB}")
	endif()
	if(NOT DEFINED CMAKE_NM)
		set(CMAKE_NM "")
	endif()

	if(NOT DEFINED CMAKE_C_FLAGS)
		set(CMAKE_C_FLAGS "")
	endif()
	if(NOT DEFINED CMAKE_CXX_FLAGS)
		set(CMAKE_CXX_FLAGS "")
	endif()

	if(NOT DEFINED PATH)
		set(PATH "")
	endif()

	set(_BM_NESTED_TOOLCHAIN_FILE "${BUILDMASTER_TOOLCHAIN_FILE}")

	if(NOT _toolchain_name STREQUAL "")
		_bm_log_message(CMAKE DEBUG "_bm_tools_cmake_stages(${_component}): TOOLCHAIN=${_toolchain_name}")
		_bm_tc_load_profile("${_toolchain_name}")

		get_filename_component(_cmake_dir "${CMAKE_COMMAND}" DIRECTORY)
		get_filename_component(_cmake_name "${CMAKE_COMMAND}" NAME)
		_bm_path_normalize(_cmake_dir "${_cmake_dir}")
		if(PATH STREQUAL "")
			set(PATH "${_cmake_dir}")
		else()
			set(PATH "${_cmake_dir};${PATH}")
		endif()

		set(CMAKE_C_COMPILER "${BM_TC_C_COMPILER}")
		set(CMAKE_CXX_COMPILER "${BM_TC_CXX_COMPILER}")
		set(CMAKE_LINKER_TYPE "${BM_TC_LINKER_TYPE}")
		set(CMAKE_LINKER "${BM_TC_LINKER}")
		set(CMAKE_C_COMPILER_LINKER "${BM_TC_LINKER}")
		set(CMAKE_CXX_COMPILER_LINKER "${BM_TC_LINKER}")
		set(CMAKE_AR "${BM_TC_AR}")
		set(CMAKE_C_COMPILER_AR "${BM_TC_AR}")
		set(CMAKE_CXX_COMPILER_AR "${BM_TC_AR}")
		set(CMAKE_RANLIB "${BM_TC_RANLIB}")
		set(CMAKE_C_COMPILER_RANLIB "${BM_TC_RANLIB}")
		set(CMAKE_CXX_COMPILER_RANLIB "${BM_TC_RANLIB}")
		set(CMAKE_NM "${BM_TC_NM}")

		if(_toolchain_name STREQUAL "msvc" OR _toolchain_name STREQUAL "clang-cl")
			if(NOT CMAKE_C_COMPILER STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_C_COMPILER}")
				_bm_tc_resolve_msvc_tool(CMAKE_C_COMPILER "${CMAKE_C_COMPILER}")
			endif()
			if(NOT CMAKE_CXX_COMPILER STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_CXX_COMPILER}")
				_bm_tc_resolve_msvc_tool(CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
			endif()
			if(NOT CMAKE_AR STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_AR}")
				_bm_tc_resolve_msvc_tool(CMAKE_AR "${CMAKE_AR}")
				set(CMAKE_C_COMPILER_AR "${CMAKE_AR}")
				set(CMAKE_CXX_COMPILER_AR "${CMAKE_AR}")
			endif()
			if(NOT CMAKE_LINKER STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_LINKER}")
				_bm_tc_resolve_msvc_tool(CMAKE_LINKER "${CMAKE_LINKER}")
				set(CMAKE_C_COMPILER_LINKER "${CMAKE_LINKER}")
				set(CMAKE_CXX_COMPILER_LINKER "${CMAKE_LINKER}")
			endif()
		endif()

		set(BM_TC_C_COMPILER "${CMAKE_C_COMPILER}")
		set(BM_TC_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
		set(BM_TC_AR "${CMAKE_AR}")
		set(BM_TC_LINKER "${CMAKE_LINKER}")
		set(BM_TC_RANLIB "${CMAKE_RANLIB}")
		set(BM_TC_NM "${CMAKE_NM}")

		set(_bm_c_in "${CMAKE_C_FLAGS}")
		set(_bm_cxx_in "${CMAKE_CXX_FLAGS}")
		_bm_tc_translate_component("${_component}" CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_EXE_LINKER_FLAGS
			"${_toolchain_name}")
		set(_bm_c_sh "${_bm_c_in}")
		set(_bm_cxx_sh "${_bm_cxx_in}")
		_bm_tc_translate_component("${_component}" _bm_c_sh _bm_cxx_sh CMAKE_SHARED_LINKER_FLAGS
			"${_toolchain_name}")
		set(_bm_c_mo "${_bm_c_in}")
		set(_bm_cxx_mo "${_bm_cxx_in}")
		_bm_tc_translate_component("${_component}" _bm_c_mo _bm_cxx_mo CMAKE_MODULE_LINKER_FLAGS
			"${_toolchain_name}")
		if(COMMAND _bm_env_update_runner)
			_bm_env_update_runner()
		endif()

		if(COMMAND _bm_env_apply_install_search_paths)
			_bm_env_apply_install_search_paths()
		endif()

		_bm_env_create_runners(
			_bm_tc_runner
			_bm_tc_runner_silent
			"${_component}"
			"${_toolchain_name}"
		)

		_bm_path_sanitize(_bm_tc_file_safe "${_component}_${_toolchain_name}")
		set(_bm_component_toolchain
			"${BUILDMASTER_SCRIPTSDIR}/toolchain_${_bm_tc_file_safe}.cmake")
		_bm_path_normalize(_bm_component_toolchain "${_bm_component_toolchain}")

		_bm_tc_write_component(
			"${_bm_component_toolchain}"
			"${_toolchain_name}"
		)

		set(_BM_NESTED_TOOLCHAIN_FILE "${_bm_component_toolchain}")
		set(_CMAKE_USE_TOOLCHAIN_FILE "1")

		set(ENV_CMAKE_COMMAND ${_bm_tc_runner} "${_cmake_name}")
		set(ENV_CMAKE_SILENT_COMMAND ${_bm_tc_runner_silent} "${_cmake_name}")
		if(BUILDMASTER_VERBOSE)
			set(ENV_CMAKE_COMPILE_COMMAND ${_bm_tc_runner} "${_cmake_name}")
		else()
			set(ENV_CMAKE_COMPILE_COMMAND ${_bm_tc_runner_silent} "${_cmake_name}")
		endif()
	else()
		set(_CMAKE_USE_TOOLCHAIN_FILE "1")
		_bm_tc_infer_profile(_bm_inherit_profile)
		set(_bm_c_in "${CMAKE_C_FLAGS}")
		set(_bm_cxx_in "${CMAKE_CXX_FLAGS}")
		_bm_tc_translate_component("${_component}" CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_EXE_LINKER_FLAGS
			"${_bm_inherit_profile}")
		set(_bm_c_sh "${_bm_c_in}")
		set(_bm_cxx_sh "${_bm_cxx_in}")
		_bm_tc_translate_component("${_component}" _bm_c_sh _bm_cxx_sh CMAKE_SHARED_LINKER_FLAGS
			"${_bm_inherit_profile}")
		set(_bm_c_mo "${_bm_c_in}")
		set(_bm_cxx_mo "${_bm_cxx_in}")
		_bm_tc_translate_component("${_component}" _bm_c_mo _bm_cxx_mo CMAKE_MODULE_LINKER_FLAGS
			"${_bm_inherit_profile}")
		if(COMMAND _bm_env_update_runner)
			_bm_env_update_runner()
		endif()
		if(COMMAND _bm_env_apply_install_search_paths)
			_bm_env_apply_install_search_paths()
		endif()
	endif()

	if(NOT DEFINED BM_TC_IPO_ON)
		set(BM_TC_IPO_ON FALSE)
	endif()
	if(NOT DEFINED BM_TC_IPO_FAT)
		set(BM_TC_IPO_FAT FALSE)
	endif()
	if(NOT DEFINED BM_TC_IPO_COMPILE_OPTIONS)
		set(BM_TC_IPO_COMPILE_OPTIONS "")
	endif()
	if(NOT DEFINED BM_TC_LINK_GROUP_START)
		set(BM_TC_LINK_GROUP_START "")
	endif()
	if(NOT DEFINED BM_TC_LINK_GROUP_END)
		set(BM_TC_LINK_GROUP_END "")
	endif()

	set(BUILDMASTER_TOOLCHAIN_FILE "${_BM_NESTED_TOOLCHAIN_FILE}")

	_bm_env_quote_cmd_list(_CMAKE_CFG_CMD_PREFIX ${ENV_CMAKE_SILENT_COMMAND})
	_bm_env_quote_cmd_list(_CMAKE_SILENT_CMD_PREFIX ${ENV_CMAKE_SILENT_COMMAND})
	_bm_env_quote_cmd_list(_CMAKE_COMPILE_CMD_PREFIX ${ENV_CMAKE_COMPILE_COMMAND})

	set(BM_COMPONENT_ENV_CMAKE_COMMAND ${ENV_CMAKE_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND ${ENV_CMAKE_SILENT_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND ${ENV_CMAKE_COMPILE_COMMAND} PARENT_SCOPE)

	if(NOT CMAKE_LINKER STREQUAL "")
		_bm_path_normalize(CMAKE_LINKER "${CMAKE_LINKER}")
	endif()
	if(NOT CMAKE_C_COMPILER_LINKER STREQUAL "")
		_bm_path_normalize(CMAKE_C_COMPILER_LINKER "${CMAKE_C_COMPILER_LINKER}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_LINKER STREQUAL "")
		_bm_path_normalize(CMAKE_CXX_COMPILER_LINKER "${CMAKE_CXX_COMPILER_LINKER}")
	endif()
	if(NOT CMAKE_MT STREQUAL "" AND NOT CMAKE_MT STREQUAL "mt")
		_bm_path_normalize(CMAKE_MT "${CMAKE_MT}")
	endif()
	if(NOT CMAKE_AR STREQUAL "")
		_bm_path_normalize(CMAKE_AR "${CMAKE_AR}")
	endif()
	if(NOT CMAKE_C_COMPILER_AR STREQUAL "")
		_bm_path_normalize(CMAKE_C_COMPILER_AR "${CMAKE_C_COMPILER_AR}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_AR STREQUAL "")
		_bm_path_normalize(CMAKE_CXX_COMPILER_AR "${CMAKE_CXX_COMPILER_AR}")
	endif()
	if(NOT CMAKE_RANLIB STREQUAL "")
		_bm_path_normalize(CMAKE_RANLIB "${CMAKE_RANLIB}")
	endif()
	if(NOT CMAKE_C_COMPILER_RANLIB STREQUAL "")
		_bm_path_normalize(CMAKE_C_COMPILER_RANLIB "${CMAKE_C_COMPILER_RANLIB}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_RANLIB STREQUAL "")
		_bm_path_normalize(CMAKE_CXX_COMPILER_RANLIB "${CMAKE_CXX_COMPILER_RANLIB}")
	endif()
	if(NOT CMAKE_NM STREQUAL "")
		_bm_path_normalize(CMAKE_NM "${CMAKE_NM}")
	endif()

	if(${_library_mode} STREQUAL "static")
		set(_CMAKE_SHARED_MODE "OFF")
	elseif(${_library_mode} STREQUAL "shared")
		set(_CMAKE_SHARED_MODE "ON")
	elseif(${_library_mode} STREQUAL "headers")
		set(_CMAKE_SHARED_MODE "OFF")
	elseif(${_library_mode} STREQUAL "executable")
		set(_CMAKE_SHARED_MODE "OFF")
	else()
		_bm_log_message(CMAKE FATAL "Unknown mode '${_library_mode}' in _bm_tools_cmake_stages (expected static, shared, headers, or executable)")
	endif()

	set(_CMAKE_COMPONENT_TITLE "${_component_title}")
	set(_CMAKE_STAGE_BUILD "${_component}_build")
	set(_CMAKE_STAGE_INSTALL "${_component}_install")
	set(_CMAKE_SRCDIR "${_srcdir}")
	set(_CMAKE_BUILD_DIR "${_builddir}")
	set(_CMAKE_OUTPUT_LIBRARIES "${_output_libraries}")

	if(BUILDMASTER_VERBOSE)
		set(_CMAKE_BUILD_VERBOSE_ARGS "--verbose")
	else()
		set(_CMAKE_BUILD_VERBOSE_ARGS "")
	endif()

	_bm_list_join(_CMAKE_OPTIONS "${_options}" "\n\t\t")
	_bm_path_sanitize(_CMAKE_COMPONENT_SAFE "${_component}")

	set(_CMAKE_GIT_POST_INSTALL_RESET "")
	if(COMMAND _bm_tools_git_marker)
		_bm_tools_git_marker(_CMAKE_GIT_POST_INSTALL_RESET "${_srcdir}")
	endif()

	_bm_install_rules_write(
		"${_component}"
		"CMAKE"
		"${_component_title}"
		"${_CMAKE_COMPONENT_SAFE}"
		"${_CMAKE_OUTPUT_LIBRARIES}"
		_BM_INSTALL_RULES)
	if("${_BM_INSTALL_RULES}" STREQUAL "" OR NOT EXISTS "${_BM_INSTALL_RULES}")
		_bm_log_message(CMAKE FATAL
			"_bm_tools_cmake_stages('${_component}'): install rules missing")
	endif()

	set(_CMAKE_CONFIGURE_FILE
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_configure.cmake"
	)
	set(_CMAKE_BUILD_FILE
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_build.cmake"
	)
	set(_CMAKE_INSTALL_FILE
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_install.cmake"
	)
	set(_CMAKE_BUILD_EXEC_SCRIPT
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_build_exec.cmake"
	)
	set(_CMAKE_INSTALL_LIBRARY_SCRIPT
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_install_library.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/templates/configure.cmake.in"
		"${_CMAKE_CONFIGURE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/templates/build_exec.cmake.in"
		"${_CMAKE_BUILD_EXEC_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/templates/install_library.cmake.in"
		"${_CMAKE_INSTALL_LIBRARY_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/templates/build.cmake.in"
		"${_CMAKE_BUILD_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/templates/install.cmake.in"
		"${_CMAKE_INSTALL_FILE}"
		@ONLY
	)

	set(${_file_configure} "${_CMAKE_CONFIGURE_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_CMAKE_BUILD_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_CMAKE_INSTALL_FILE}" PARENT_SCOPE)
	_bm_log_message(CMAKE LOWLEVEL "Exiting _bm_tools_cmake_stages")
endfunction()
