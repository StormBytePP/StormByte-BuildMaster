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
## @param[in] _indent_level Optional (passed as ARGV10) number of tab
##            characters to prepend to generated lines; when provided
##            `_MESON_INDENT_` is set for template use.
function(create_meson_stages _file_setup _file_compile _file_install _component _component_title _srcdir _builddir _meson_options _library_mode _output_libraries)
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
		string(REPEAT "\t" ${_indent_level} _MESON_INDENT_)
	else()
		set(_MESON_INDENT_ "")
	endif()

	if(${_library_mode} STREQUAL "static")
		set(_MESON_LIBRARY_TYPE "static")
		list(APPEND _meson_options "-Db_staticpic=true")
	elseif(${_library_mode} STREQUAL "shared")
		set(_MESON_LIBRARY_TYPE "shared")
	elseif(${_library_mode} STREQUAL "headers")
		# Header-only: Meson still wants default_library; static is least surprising.
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
	if(MSVC)
		string(APPEND _MESON_C_ARGS " /Z7")
		string(APPEND _MESON_CXX_ARGS " /Z7")
	endif()

	# ------------------------------------------------------------------
	# Link args: parent flags + LLD (clang-cl / clang IPO) or MSVC link,
	# or an explicit CMAKE_LINKER path.
	# ------------------------------------------------------------------
	if(NOT DEFINED CMAKE_EXE_LINKER_FLAGS)
		set(CMAKE_EXE_LINKER_FLAGS "")
	endif()
	set(_MESON_LINK_ARGS "${CMAKE_EXE_LINKER_FLAGS}")

	if(DEFINED CMAKE_LINKER_TYPE AND CMAKE_LINKER_TYPE STREQUAL "LLD")
		# Windows clang-cl → lld-link; Linux clang → ld.lld via -fuse-ld=lld
		if(WIN32)
			string(APPEND _MESON_LINK_ARGS " -fuse-ld=lld-link")
		else()
			string(APPEND _MESON_LINK_ARGS " -fuse-ld=lld")
		endif()
	elseif(DEFINED CMAKE_LINKER_TYPE AND CMAKE_LINKER_TYPE STREQUAL "MSVC")
		string(APPEND _MESON_LINK_ARGS " -fuse-ld=link")
	elseif(DEFINED CMAKE_LINKER AND NOT CMAKE_LINKER STREQUAL "")
		normalize_cmake_path(_bm_meson_linker "${CMAKE_LINKER}")
		string(APPEND _MESON_LINK_ARGS " -fuse-ld=${_bm_meson_linker}")
	endif()

	string(STRIP "${_MESON_LINK_ARGS}" _MESON_LINK_ARGS)

	# Archiver for Meson (static + LTO): prefer CMAKE_AR, else ENV{AR}
	if(DEFINED CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
		normalize_cmake_path(_MESON_AR "${CMAKE_AR}")
	elseif(DEFINED ENV{AR} AND NOT "$ENV{AR}" STREQUAL "")
		normalize_cmake_path(_MESON_AR "$ENV{AR}")
	else()
		set(_MESON_AR "")
	endif()
	if(DEFINED CMAKE_RANLIB AND NOT CMAKE_RANLIB STREQUAL "")
		normalize_cmake_path(_MESON_RANLIB "${CMAKE_RANLIB}")
	elseif(DEFINED ENV{RANLIB} AND NOT "$ENV{RANLIB}" STREQUAL "")
		normalize_cmake_path(_MESON_RANLIB "$ENV{RANLIB}")
	else()
		set(_MESON_RANLIB "")
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
