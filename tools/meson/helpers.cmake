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
## @param[in] _indent_level Optional (ARGV10) number of tab characters to
##            prepend to generated lines; sets `_MESON_INDENT_` for templates.
## @param[in] _toolchain Optional (ARGV11) BuildMaster toolchain name
##            (`gcc`, `clang`, `clang-cl`, `msvc`). Empty means inherit the
##            parent job toolchain. When set, compilers, linker, archiver and
##            component-local env runners apply only to this component's stages.
## @param[in] _configure_via_target Optional (ARGV12) `"1"` when setup runs
##            under a dependant custom target (suppress hierarchical STATUS).
##            `"0"` or empty otherwise.
## @note Always exports BM_COMPONENT_ENV_CMAKE_* (outer dependant -P uses
##       cmake) and BM_COMPONENT_ENV_MESON_* in the parent scope so library
##       fragments and stage scripts share the same runners.
function(create_meson_stages _file_setup _file_compile _file_install _component _component_title _srcdir _builddir _meson_options _library_mode _output_libraries)
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
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

	buildmaster_validate_toolchain(_toolchain_name "${_toolchain_raw}")

	if(NOT _toolchain_name STREQUAL "")
		set(_MESON_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain_name})")
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
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_meson_stages (expected static, shared, or headers)")
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
		buildmaster_load_toolchain_profile("${_toolchain_name}")

		# Short tool names + bindirs on PATH (avoid paths with spaces via cmd)
		get_filename_component(_cmake_dir "${CMAKE_COMMAND}" DIRECTORY)
		get_filename_component(_cmake_name "${CMAKE_COMMAND}" NAME)
		normalize_cmake_path(_cmake_dir "${_cmake_dir}")
		if(MESON_EXECUTABLE)
			get_filename_component(_meson_dir "${MESON_EXECUTABLE}" DIRECTORY)
			get_filename_component(_meson_name "${MESON_EXECUTABLE}" NAME)
			normalize_cmake_path(_meson_dir "${_meson_dir}")
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
				buildmaster_resolve_msvc_tool(_bm_c_compiler "${_bm_c_compiler}")
			endif()
			if(NOT _bm_cxx_compiler STREQUAL "" AND NOT IS_ABSOLUTE "${_bm_cxx_compiler}")
				buildmaster_resolve_msvc_tool(_bm_cxx_compiler "${_bm_cxx_compiler}")
			endif()
			if(NOT _MESON_AR STREQUAL "" AND NOT IS_ABSOLUTE "${_MESON_AR}")
				buildmaster_resolve_msvc_tool(_MESON_AR "${_MESON_AR}")
			endif()
			if(DEFINED BM_TC_LINKER AND NOT BM_TC_LINKER STREQUAL "" AND NOT IS_ABSOLUTE "${BM_TC_LINKER}")
				buildmaster_resolve_msvc_tool(BM_TC_LINKER "${BM_TC_LINKER}")
			endif()
		endif()

		# BM_TC_* must match resolved values for the component runner bat/sh
		set(BM_TC_C_COMPILER "${_bm_c_compiler}")
		set(BM_TC_CXX_COMPILER "${_bm_cxx_compiler}")
		set(BM_TC_AR "${_MESON_AR}")
		if(NOT _MESON_RANLIB STREQUAL "")
			set(BM_TC_RANLIB "${_MESON_RANLIB}")
		endif()

		buildmaster_create_component_env_runners(
			_bm_tc_runner
			_bm_tc_runner_silent
			"${_component}"
			"${_toolchain_name}"
		)

		if(NOT _MESON_AR STREQUAL "")
			normalize_cmake_path(_MESON_AR "${_MESON_AR}")
		endif()
		if(NOT _MESON_RANLIB STREQUAL "")
			normalize_cmake_path(_MESON_RANLIB "${_MESON_RANLIB}")
		endif()

		buildmaster_clean_ldflags(_MESON_LINK_ARGS
			"${_MESON_LINK_ARGS}" "${_toolchain_name}")
		buildmaster_clean_cflags(CMAKE_C_FLAGS
			"${CMAKE_C_FLAGS}" "${_toolchain_name}")
		buildmaster_clean_cflags(CMAKE_CXX_FLAGS
			"${CMAKE_CXX_FLAGS}" "${_toolchain_name}")

		# -fuse-ld= must be a driver flavor name, never an absolute path
		if(BM_TC_FORCE_LLD)
			buildmaster_fuse_ld_flag(_bm_fuse_ld "LLD" "")
		elseif(_toolchain_name STREQUAL "msvc")
			buildmaster_fuse_ld_flag(_bm_fuse_ld "MSVC" "")
		else()
			set(_bm_tc_lt "")
			if(DEFINED BM_TC_LINKER_TYPE)
				set(_bm_tc_lt "${BM_TC_LINKER_TYPE}")
			endif()
			set(_bm_tc_lnk "")
			if(DEFINED BM_TC_LINKER)
				set(_bm_tc_lnk "${BM_TC_LINKER}")
			endif()
			buildmaster_fuse_ld_flag(_bm_fuse_ld "${_bm_tc_lt}" "${_bm_tc_lnk}")
		endif()
		if(NOT _bm_fuse_ld STREQUAL "")
			string(APPEND _MESON_LINK_ARGS " ${_bm_fuse_ld}")
		endif()

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
			buildmaster_clean_ldflags(_MESON_LINK_ARGS
				"${_MESON_LINK_ARGS}" "clang-cl")
			buildmaster_clean_cflags(CMAKE_C_FLAGS
				"${CMAKE_C_FLAGS}" "clang-cl")
			buildmaster_clean_cflags(CMAKE_CXX_FLAGS
				"${CMAKE_CXX_FLAGS}" "clang-cl")
		endif()

		set(_bm_lt "")
		if(DEFINED CMAKE_LINKER_TYPE)
			set(_bm_lt "${CMAKE_LINKER_TYPE}")
		endif()
		set(_bm_lnk "")
		if(DEFINED CMAKE_LINKER)
			set(_bm_lnk "${CMAKE_LINKER}")
		endif()
		buildmaster_fuse_ld_flag(_bm_fuse_ld "${_bm_lt}" "${_bm_lnk}")
		if(NOT _bm_fuse_ld STREQUAL "")
			string(APPEND _MESON_LINK_ARGS " ${_bm_fuse_ld}")
		endif()

		if(DEFINED CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
			normalize_cmake_path(_MESON_AR "${CMAKE_AR}")
		elseif(DEFINED ENV{AR} AND NOT "$ENV{AR}" STREQUAL "")
			normalize_cmake_path(_MESON_AR "$ENV{AR}")
		endif()
		if(DEFINED CMAKE_RANLIB AND NOT CMAKE_RANLIB STREQUAL "")
			normalize_cmake_path(_MESON_RANLIB "${CMAKE_RANLIB}")
		elseif(DEFINED ENV{RANLIB} AND NOT "$ENV{RANLIB}" STREQUAL "")
			normalize_cmake_path(_MESON_RANLIB "$ENV{RANLIB}")
		endif()
	endif()

	string(STRIP "${_MESON_LINK_ARGS}" _MESON_LINK_ARGS)

	buildmaster_quote_cmd_list_for_script(_MESON_CMD_PREFIX ${ENV_MESON_COMMAND})
	buildmaster_quote_cmd_list_for_script(_MESON_SILENT_CMD_PREFIX ${ENV_MESON_SILENT_COMMAND})
	buildmaster_quote_cmd_list_for_script(_MESON_COMPILE_CMD_PREFIX ${ENV_MESON_COMPILE_COMMAND})

	if(CMAKE_BUILD_TYPE STREQUAL "Release" AND CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
		set(LTO_ENABLED "true")
	else()
		set(LTO_ENABLED "false")
	endif()

	if(BUILDMASTER_VERBOSE)
		set(_MESON_COMPILE_VERBOSE_ARGS "-v")
	else()
		set(_MESON_COMPILE_VERBOSE_ARGS "")
	endif()

	list_join(_MESON_OPTIONS "${_meson_options}" " ")
	sanitize_for_filename(_MESON_COMPONENT_SAFE "${_component}")

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
	if(COMMAND buildmaster_git_post_install_marker_for_srcdir)
		buildmaster_git_post_install_marker_for_srcdir(_MESON_GIT_POST_INSTALL_RESET "${_srcdir}")
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
	set(_MESON_INSTALL_EXEC_SCRIPT
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_install_exec.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/setup.cmake.in"
		"${_MESON_SETUP_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/compile_exec.cmake.in"
		"${_MESON_COMPILE_EXEC_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/install_exec.cmake.in"
		"${_MESON_INSTALL_EXEC_SCRIPT}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/compile.cmake.in"
		"${_MESON_COMPILE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/install.cmake.in"
		"${_MESON_INSTALL_FILE}"
		@ONLY
	)

	set(${_file_setup} "${_MESON_SETUP_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_MESON_COMPILE_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_MESON_INSTALL_FILE}" PARENT_SCOPE)
endfunction()
