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
## @param[in] _indent_level Optional (ARGV10) number of tab characters to
##            prepend to generated lines; sets `_CMAKE_INDENT_` for templates.
## @param[in] _toolchain Optional (ARGV11) BuildMaster toolchain name
##            (`gcc`, `clang`, `clang-cl`, `msvc`). Empty means inherit the
##            parent job toolchain. When set, a component-local toolchain
##            file is generated that keeps the parent BUILDMASTER_* install
##            paths (unified tree) while applying this profile's compilers
##            and binutils; the parent toolchain.cmake is not loaded (avoids
##            FORCE of parent AR/LINKER).
## @param[in] _configure_via_target Optional (ARGV12) `"1"` when configure
##            runs under a dependant custom target (suppress hierarchical
##            STATUS; the target COMMENT is enough). `"0"` or empty otherwise.
## @note Always exports BM_COMPONENT_ENV_CMAKE_COMMAND,
##       BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND and
##       BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND in the parent scope so
##       component library fragments (including dependant targets) use the
##       same runners as the generated stage scripts.
function(create_cmake_stages _file_configure _file_compile _file_install _component _component_title _srcdir _builddir _options _library_mode _output_libraries)
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
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

	buildmaster_validate_toolchain(_toolchain_name "${_toolchain_raw}")

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

	# Path used by configure.cmake.in as -DCMAKE_TOOLCHAIN_FILE=...
	# Default: parent BuildMaster toolchain (unified install paths).
	set(_BM_NESTED_TOOLCHAIN_FILE "${BUILDMASTER_TOOLCHAIN_FILE}")

	if(NOT _toolchain_name STREQUAL "")
		buildmaster_load_toolchain_profile("${_toolchain_name}")

		get_filename_component(_cmake_dir "${CMAKE_COMMAND}" DIRECTORY)
		get_filename_component(_cmake_name "${CMAKE_COMMAND}" NAME)
		normalize_cmake_path(_cmake_dir "${_cmake_dir}")
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
				buildmaster_resolve_msvc_tool(CMAKE_C_COMPILER "${CMAKE_C_COMPILER}")
			endif()
			if(NOT CMAKE_CXX_COMPILER STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_CXX_COMPILER}")
				buildmaster_resolve_msvc_tool(CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
			endif()
			if(NOT CMAKE_AR STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_AR}")
				buildmaster_resolve_msvc_tool(CMAKE_AR "${CMAKE_AR}")
				set(CMAKE_C_COMPILER_AR "${CMAKE_AR}")
				set(CMAKE_CXX_COMPILER_AR "${CMAKE_AR}")
			endif()
			if(NOT CMAKE_LINKER STREQUAL "" AND NOT IS_ABSOLUTE "${CMAKE_LINKER}")
				buildmaster_resolve_msvc_tool(CMAKE_LINKER "${CMAKE_LINKER}")
				set(CMAKE_C_COMPILER_LINKER "${CMAKE_LINKER}")
				set(CMAKE_CXX_COMPILER_LINKER "${CMAKE_LINKER}")
			endif()
		endif()

		# BM_TC_* must match resolved values for the component runner bat/sh
		set(BM_TC_C_COMPILER "${CMAKE_C_COMPILER}")
		set(BM_TC_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
		set(BM_TC_AR "${CMAKE_AR}")
		set(BM_TC_LINKER "${CMAKE_LINKER}")
		set(BM_TC_RANLIB "${CMAKE_RANLIB}")
		set(BM_TC_NM "${CMAKE_NM}")

		buildmaster_create_component_env_runners(
			_bm_tc_runner
			_bm_tc_runner_silent
			"${_component}"
			"${_toolchain_name}"
		)

		buildmaster_clean_ldflags(CMAKE_EXE_LINKER_FLAGS
			"${CMAKE_EXE_LINKER_FLAGS}" "${_toolchain_name}")
		buildmaster_clean_ldflags(CMAKE_SHARED_LINKER_FLAGS
			"${CMAKE_SHARED_LINKER_FLAGS}" "${_toolchain_name}")
		buildmaster_clean_ldflags(CMAKE_MODULE_LINKER_FLAGS
			"${CMAKE_MODULE_LINKER_FLAGS}" "${_toolchain_name}")

		buildmaster_clean_cflags(CMAKE_C_FLAGS
			"${CMAKE_C_FLAGS}" "${_toolchain_name}")
		buildmaster_clean_cflags(CMAKE_CXX_FLAGS
			"${CMAKE_CXX_FLAGS}" "${_toolchain_name}")

		# Component toolchain: parent BUILDMASTER_* paths (never a nested install
		# tree) + this profile's compilers/binutils. Do not include parent
		# toolchain.cmake (FORCE of parent AR/LINKER would fight the override).
		sanitize_for_filename(_bm_tc_file_safe "${_component}_${_toolchain_name}")
		set(_bm_component_toolchain
			"${BUILDMASTER_SCRIPTSDIR}/toolchain_${_bm_tc_file_safe}.cmake")
		normalize_cmake_path(_bm_component_toolchain "${_bm_component_toolchain}")

		set(_bm_tt "")
		string(APPEND _bm_tt
			"# Auto-generated by BuildMaster – component TOOLCHAIN=${_toolchain_name}\n"
			"# Unified parent install tree; compilers from profile ${_toolchain_name}.\n"
			"set(BUILDMASTER_CONFIGURED TRUE)\n"
			"set(BUILDMASTER_SRCDIR \"${BUILDMASTER_SRCDIR}\")\n"
			"set(BUILDMASTER_BINDIR \"${BUILDMASTER_BINDIR}\")\n"
			"set(BUILDMASTER_SCRIPTSDIR \"${BUILDMASTER_SCRIPTSDIR}\")\n"
			"set(BUILDMASTER_DOWNLOADSDIR \"${BUILDMASTER_DOWNLOADSDIR}\")\n"
			"set(BUILDMASTER_TOOLCHAIN_FILE \"${BUILDMASTER_TOOLCHAIN_FILE}\")\n"
			"set(BUILDMASTER_INSTALL_DIR \"${BUILDMASTER_INSTALL_DIR}\")\n"
			"set(BUILDMASTER_INSTALL_LIBDIR \"${BUILDMASTER_INSTALL_LIBDIR}\")\n"
			"set(BUILDMASTER_INSTALL_BINDIR \"${BUILDMASTER_INSTALL_BINDIR}\")\n"
			"set(BUILDMASTER_INSTALL_INCLUDEDIR \"${BUILDMASTER_INSTALL_INCLUDEDIR}\")\n"
			"set(BUILDMASTER_MARKERS_DIR \"${BUILDMASTER_MARKERS_DIR}\")\n"
			"set(BUILDMASTER_FAIL_MARKER \"${BUILDMASTER_FAIL_MARKER}\")\n"
			"set(BUILDMASTER_DEBUG \"${BUILDMASTER_DEBUG}\")\n"
			"set(BUILDMASTER_VERBOSE \"${BUILDMASTER_VERBOSE}\")\n"
			"set(BUILDMASTER_FAIL_FAST \"${BUILDMASTER_FAIL_FAST}\")\n"
			"set(BUILDMASTER_CLEAN_RESET_REPOS \"${BUILDMASTER_CLEAN_RESET_REPOS}\")\n"
			"set(BUILDMASTER_GIT_CONFIGURE_STAMP \"${BUILDMASTER_GIT_CONFIGURE_STAMP}\")\n"
			"set(BUILDMASTER_TOOLCHAIN_SRCDIR \"${BUILDMASTER_TOOLCHAIN_SRCDIR}\")\n"
			"set(BUILDMASTER_TOOLCHAIN_PROFILES_DIR \"${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}\")\n"
			"set(BUILDMASTER_KNOWN_TOOLCHAINS \"${BUILDMASTER_KNOWN_TOOLCHAINS}\")\n"
			"set(BUILDMASTER_ENV_SRCDIR \"${BUILDMASTER_ENV_SRCDIR}\")\n"
			"set(BUILDMASTER_SCRIPTS_ENVDIR \"${BUILDMASTER_SCRIPTS_ENVDIR}\")\n"
			"set(BUILDMASTER_COMPONENT_SRCDIR \"${BUILDMASTER_COMPONENT_SRCDIR}\")\n"
			"set(BUILDMASTER_SCRIPTS_COMPONENTDIR \"${BUILDMASTER_SCRIPTS_COMPONENTDIR}\")\n"
			"set(BUILDMASTER_TOOLS_SRCDIR \"${BUILDMASTER_TOOLS_SRCDIR}\")\n"
			"set(BUILDMASTER_SCRIPTS_CMAKEDIR \"${BUILDMASTER_SCRIPTS_CMAKEDIR}\")\n"
		)
		if(NOT CMAKE_C_COMPILER STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_C_COMPILER \"${CMAKE_C_COMPILER}\" CACHE FILEPATH \"\" FORCE)\n")
		endif()
		if(NOT CMAKE_CXX_COMPILER STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_CXX_COMPILER \"${CMAKE_CXX_COMPILER}\" CACHE FILEPATH \"\" FORCE)\n")
		endif()
		if(NOT CMAKE_LINKER_TYPE STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_LINKER_TYPE \"${CMAKE_LINKER_TYPE}\" CACHE STRING \"\" FORCE)\n")
		endif()
		if(NOT CMAKE_LINKER STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_LINKER \"${CMAKE_LINKER}\" CACHE FILEPATH \"\" FORCE)\n"
				"set(CMAKE_C_COMPILER_LINKER \"${CMAKE_C_COMPILER_LINKER}\" CACHE FILEPATH \"\" FORCE)\n"
				"set(CMAKE_CXX_COMPILER_LINKER \"${CMAKE_CXX_COMPILER_LINKER}\" CACHE FILEPATH \"\" FORCE)\n")
		endif()
		if(NOT CMAKE_AR STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_AR \"${CMAKE_AR}\" CACHE FILEPATH \"\" FORCE)\n"
				"set(CMAKE_C_COMPILER_AR \"${CMAKE_C_COMPILER_AR}\" CACHE FILEPATH \"\" FORCE)\n"
				"set(CMAKE_CXX_COMPILER_AR \"${CMAKE_CXX_COMPILER_AR}\" CACHE FILEPATH \"\" FORCE)\n")
		endif()
		if(NOT CMAKE_RANLIB STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_RANLIB \"${CMAKE_RANLIB}\" CACHE FILEPATH \"\" FORCE)\n")
		endif()
		if(NOT CMAKE_NM STREQUAL "")
			string(APPEND _bm_tt
				"set(CMAKE_NM \"${CMAKE_NM}\" CACHE FILEPATH \"\" FORCE)\n")
		endif()
		file(WRITE "${_bm_component_toolchain}" "${_bm_tt}")

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
	endif()

	# configure.cmake.in substitutes @BUILDMASTER_TOOLCHAIN_FILE@ for the nested
	# -DCMAKE_TOOLCHAIN_FILE=... (parent tree or component override file).
	set(BUILDMASTER_TOOLCHAIN_FILE "${_BM_NESTED_TOOLCHAIN_FILE}")

	buildmaster_quote_cmd_list_for_script(_CMAKE_CFG_CMD_PREFIX ${ENV_CMAKE_SILENT_COMMAND})
	buildmaster_quote_cmd_list_for_script(_CMAKE_SILENT_CMD_PREFIX ${ENV_CMAKE_SILENT_COMMAND})
	buildmaster_quote_cmd_list_for_script(_CMAKE_COMPILE_CMD_PREFIX ${ENV_CMAKE_COMPILE_COMMAND})

	set(BM_COMPONENT_ENV_CMAKE_COMMAND ${ENV_CMAKE_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND ${ENV_CMAKE_SILENT_COMMAND} PARENT_SCOPE)
	set(BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND ${ENV_CMAKE_COMPILE_COMMAND} PARENT_SCOPE)

	if(NOT CMAKE_LINKER STREQUAL "")
		normalize_cmake_path(CMAKE_LINKER "${CMAKE_LINKER}")
	endif()
	if(NOT CMAKE_C_COMPILER_LINKER STREQUAL "")
		normalize_cmake_path(CMAKE_C_COMPILER_LINKER "${CMAKE_C_COMPILER_LINKER}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_LINKER STREQUAL "")
		normalize_cmake_path(CMAKE_CXX_COMPILER_LINKER "${CMAKE_CXX_COMPILER_LINKER}")
	endif()
	if(NOT CMAKE_MT STREQUAL "" AND NOT CMAKE_MT STREQUAL "mt")
		normalize_cmake_path(CMAKE_MT "${CMAKE_MT}")
	endif()
	if(NOT CMAKE_AR STREQUAL "")
		normalize_cmake_path(CMAKE_AR "${CMAKE_AR}")
	endif()
	if(NOT CMAKE_C_COMPILER_AR STREQUAL "")
		normalize_cmake_path(CMAKE_C_COMPILER_AR "${CMAKE_C_COMPILER_AR}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_AR STREQUAL "")
		normalize_cmake_path(CMAKE_CXX_COMPILER_AR "${CMAKE_CXX_COMPILER_AR}")
	endif()
	if(NOT CMAKE_RANLIB STREQUAL "")
		normalize_cmake_path(CMAKE_RANLIB "${CMAKE_RANLIB}")
	endif()
	if(NOT CMAKE_C_COMPILER_RANLIB STREQUAL "")
		normalize_cmake_path(CMAKE_C_COMPILER_RANLIB "${CMAKE_C_COMPILER_RANLIB}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_RANLIB STREQUAL "")
		normalize_cmake_path(CMAKE_CXX_COMPILER_RANLIB "${CMAKE_CXX_COMPILER_RANLIB}")
	endif()
	if(NOT CMAKE_NM STREQUAL "")
		normalize_cmake_path(CMAKE_NM "${CMAKE_NM}")
	endif()

	if(${_library_mode} STREQUAL "static")
		set(_CMAKE_SHARED_MODE "OFF")
	elseif(${_library_mode} STREQUAL "shared")
		set(_CMAKE_SHARED_MODE "ON")
	elseif(${_library_mode} STREQUAL "headers")
		set(_CMAKE_SHARED_MODE "OFF")
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_cmake_stages (expected static, shared, or headers)")
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

	list_join(_CMAKE_OPTIONS "${_options}" "\n\t\t")
	sanitize_for_filename(_CMAKE_COMPONENT_SAFE "${_component}")

	set(_CMAKE_GIT_POST_INSTALL_RESET "")
	if(COMMAND buildmaster_git_post_install_marker_for_srcdir)
		buildmaster_git_post_install_marker_for_srcdir(_CMAKE_GIT_POST_INSTALL_RESET "${_srcdir}")
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
	set(_CMAKE_INSTALL_EXEC_SCRIPT
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_install_exec.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/configure.cmake.in"
		"${_CMAKE_CONFIGURE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/build_exec.cmake.in"
		"${_CMAKE_BUILD_EXEC_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/install_exec.cmake.in"
		"${_CMAKE_INSTALL_EXEC_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/build.cmake.in"
		"${_CMAKE_BUILD_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/install.cmake.in"
		"${_CMAKE_INSTALL_FILE}"
		@ONLY
	)

	set(${_file_configure} "${_CMAKE_CONFIGURE_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_CMAKE_BUILD_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_CMAKE_INSTALL_FILE}" PARENT_SCOPE)
endfunction()
