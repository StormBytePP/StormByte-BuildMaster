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
## @param[in] _indent_level Optional (passed as ARGV10) number of tab
##            characters to prepend to generated lines; sets `_CMAKE_INDENT_`
##            for templates when provided.
function(create_cmake_stages _file_configure _file_compile _file_install _component _component_title _srcdir _builddir _options _library_mode _output_libraries)
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
		string(REPEAT "\t" ${_indent_level} _CMAKE_INDENT_)
	else()
		set(_CMAKE_INDENT_ "")
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

	# Linker: inherit parent (CI may force LLD for clang-cl / clang, or MSVC link.exe).
	# Empty on platforms that do not set them is fine.
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

	# Archiver / ranlib / nm (clang-cl + LTO static libs → llvm-lib / llvm-ar)
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

	# Windows paths from CI often use backslashes; CMake treats \P \M etc. as escapes.
	# normalize_cmake_path → forward slashes (safe in -D and generated scripts).
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
		# Header-only: BUILD_SHARED_LIBS is irrelevant; OFF is a harmless default.
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

	# Post-install git reset marker only (git itself runs at parent configure via include)
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
