# Include GNUInstallDirs for standard installation directory variables
include(GNUInstallDirs)

## @brief Build a platform-correct shared-library filename for a component.
## @param[out] out_var Parent-scope variable that will receive the final path.
## @param[in] lib_name Base library name without platform affixes (for
##            example: avcodec).
## @param[in] prefix_path Optional directory prefix to use instead of
##            `${BUILDMASTER_INSTALL_LIBDIR}`.
function(library_import_hint _lib_full_path _lib_name)
	if(ARGC GREATER 2)
		set(_full_prefix_path "${ARGV2}")
	else()
		set(_full_prefix_path "${BUILDMASTER_INSTALL_LIBDIR}")
	endif()

	if (MSVC)
		set(_prefix "${_full_prefix_path}/${CMAKE_IMPORT_LIBRARY_PREFIX}")
		set(_suffix "${CMAKE_IMPORT_LIBRARY_SUFFIX}")
	else()
		set(_prefix "${_full_prefix_path}/${CMAKE_SHARED_LIBRARY_PREFIX}")
		set(_suffix "${CMAKE_SHARED_LIBRARY_SUFFIX}")
	endif()

	set(${_lib_full_path} "${_prefix}${_lib_name}${_suffix}" PARENT_SCOPE)
endfunction()

## @brief Compose the canonical static-library filename for a component.
## @param[out] out_var Parent-scope variable that will receive the resulting path.
## @param[in] lib_name Base library name without prefixes/suffixes.
## @param[in] prefix_path Optional directory prefix to use instead of
##            `${BUILDMASTER_INSTALL_LIBDIR}`.
function(library_import_static_hint _lib_full_path _lib_name)
	if(ARGC GREATER 2)
		set(_full_prefix_path "${ARGV2}")
	else()
		set(_full_prefix_path "${BUILDMASTER_INSTALL_LIBDIR}")
	endif()

	set(_prefix "${_full_prefix_path}/${CMAKE_STATIC_LIBRARY_PREFIX}")
	set(_suffix "${CMAKE_STATIC_LIBRARY_SUFFIX}")

	set(${_lib_full_path} "${_prefix}${_lib_name}${_suffix}" PARENT_SCOPE)
endfunction()

## @brief MSVC-only helper to build a DLL filename for a component.
## @param[out] out_var Parent-scope variable that will receive the DLL path.
## @param[in] lib_name Base library name without prefixes/suffixes.
## @param[in] prefix_path Optional directory to use instead of
##            `${BUILDMASTER_INSTALL_BINDIR}`.
function(library_dll_hint _lib_full_path _lib_name)
	if(NOT MSVC)
		message(FATAL_ERROR "library_dll_hint is only applicable on MSVC platforms")
	endif()
	if(ARGC GREATER 2)
		set(_full_prefix_path "${ARGV2}")
	else()
		set(_full_prefix_path "${BUILDMASTER_INSTALL_BINDIR}")
	endif()

	set(_prefix "${_full_prefix_path}/${CMAKE_SHARED_LIBRARY_PREFIX}")
	set(_suffix "${CMAKE_SHARED_LIBRARY_SUFFIX}")

	set(${_lib_full_path} "${_prefix}${_lib_name}${_suffix}" PARENT_SCOPE)
endfunction()

## @brief Generate a per-component generator fragment and IMPORTED target wiring.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _build_system `cmake` or `meson`.
## @param[in] _subcomponents List of subcomponent names (ignored for headers).
## @param[in] _dependency Optional install-target dependency for dependant templates.
## @param[in] indent_level Optional (ARGV10) indentation for configure STATUS lines.
## @param[in] toolchain Optional (ARGV11) BuildMaster toolchain name
##            (`gcc`, `clang`, `clang-cl`, `msvc`). Empty inherits the parent job.
function(create_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _build_system _subcomponents _dependency)
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
	else()
		set(_indent_level 0)
	endif()

	if(ARGC GREATER 11)
		set(_toolchain "${ARGV11}")
	else()
		set(_toolchain "")
	endif()

	if(NOT _dependency STREQUAL "")
		set(_indent_level 0)
	endif()

	if(NOT _dependency STREQUAL "")
		set(_BM_CONFIGURE_VIA_TARGET "1")
	else()
		set(_BM_CONFIGURE_VIA_TARGET "0")
	endif()

	# Dependant COMMENT suffix; empty when no per-component TOOLCHAIN.
	string(STRIP "${_toolchain}" _bm_tc_disp)
	string(TOLOWER "${_bm_tc_disp}" _bm_tc_disp)
	if(NOT _bm_tc_disp STREQUAL "")
		set(_LIBRARY_TOOLCHAIN_SUFFIX " (with toolchain ${_bm_tc_disp})")
	else()
		set(_LIBRARY_TOOLCHAIN_SUFFIX "")
	endif()

	set(_LIBRARY_NAME "${_component}")
	string(TOLOWER "${_library_mode}" _library_mode)
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	if(NOT _dependency STREQUAL "")
		set(_LIBRARY_CONFIGURE_TARGET "${_component}_configure")
		set(_LIBRARY_BUILD_TARGET "${_component}_build")
		set(_component_suffix "_dependant")
	else()
		set(_component_suffix "")
	endif()

	if(_library_mode STREQUAL "static")
		set(_LIBRARY_GENERATOR_FILE "component_static${_component_suffix}.cmake.in")
		set(_LIBRARY_COMPONENT_NAMES "")
		set(_LIBRARY_COMPONENT_FILES "")
		foreach(_subcomponent IN LISTS _subcomponents)
			list(APPEND _LIBRARY_COMPONENT_NAMES "${_subcomponent}_component")
			library_import_static_hint(_LIBRARY_FILE_SUB "${_subcomponent}")
			list(APPEND _LIBRARY_COMPONENT_FILES "${_LIBRARY_FILE_SUB}")
		endforeach()
	elseif(_library_mode STREQUAL "shared")
		set(_LIBRARY_GENERATOR_FILE "component_shared${_component_suffix}.cmake.in")
		set(_LIBRARY_COMPONENT_NAMES "")
		set(_LIBRARY_COMPONENT_FILES "")
		set(_LIBRARY_COMPONENT_DLL_FILES "")
		foreach(_subcomponent IN LISTS _subcomponents)
			list(APPEND _LIBRARY_COMPONENT_NAMES "${_subcomponent}_component")
			library_import_hint(_LIBRARY_FILE_SUB "${_subcomponent}")
			list(APPEND _LIBRARY_COMPONENT_FILES "${_LIBRARY_FILE_SUB}")
			if(MSVC)
				library_dll_hint(_LIBRARY_DLL_FILE_SUB "${_subcomponent}")
				list(APPEND _LIBRARY_COMPONENT_DLL_FILES "${_LIBRARY_DLL_FILE_SUB}")
			endif()
		endforeach()
	elseif(_library_mode STREQUAL "headers")
		set(_LIBRARY_GENERATOR_FILE "component_headers${_component_suffix}.cmake.in")
		set(_LIBRARY_COMPONENT_NAMES "")
		set(_LIBRARY_COMPONENT_FILES "${_builddir}/.buildmaster_headers_installed")
		set(_LIBRARY_COMPONENT_DLL_FILES "")
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_component (expected static, shared, or headers)")
	endif()

	if(_build_system STREQUAL "cmake")
		create_cmake_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE
			"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
			"${_options}" "${_library_mode}" "${_LIBRARY_COMPONENT_FILES}"
			"${_indent_level}" "${_toolchain}" "${_BM_CONFIGURE_VIA_TARGET}")
	elseif(_build_system STREQUAL "meson")
		create_meson_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE
			"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
			"${_options}" "${_library_mode}" "${_LIBRARY_COMPONENT_FILES}"
			"${_indent_level}" "${_toolchain}" "${_BM_CONFIGURE_VIA_TARGET}")
	else()
		message(FATAL_ERROR "Unknown build system '${_build_system}' in create_component")
	endif()

	# Stage helpers export BM_COMPONENT_ENV_* for this component (global or override).
	# Dependant library fragments expand @ENV_CMAKE_SILENT_COMMAND@ for outer -P.
	if(DEFINED BM_COMPONENT_ENV_CMAKE_COMMAND)
		set(ENV_CMAKE_COMMAND ${BM_COMPONENT_ENV_CMAKE_COMMAND})
	endif()
	if(DEFINED BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND)
		set(ENV_CMAKE_SILENT_COMMAND ${BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND})
	endif()
	if(DEFINED BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND)
		set(ENV_CMAKE_COMPILE_COMMAND ${BM_COMPONENT_ENV_CMAKE_COMPILE_COMMAND})
	endif()

	sanitize_for_filename(_LIBRARY_COMPONENT_SAFE "${_component}")
	set(_LIBRARY_CREATE_FILE "${BUILDMASTER_SCRIPTS_COMPONENTDIR}/${_LIBRARY_COMPONENT_SAFE}_library.cmake")
	set(_LIBRARY_DEPENDENCIES "${_dependency}")

	configure_file(
		"${BUILDMASTER_COMPONENT_SRCDIR}/${_LIBRARY_GENERATOR_FILE}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()

## @brief CMake component wrapper (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV8).
## @param[in] toolchain Optional (ARGV9) BuildMaster toolchain name.
function(create_cmake_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents)
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 9)
		set(_toolchain "${ARGV9}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"cmake"
		"${_subcomponents}"
		""
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Meson component wrapper (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV8).
## @param[in] toolchain Optional (ARGV9) BuildMaster toolchain name.
function(create_meson_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents)
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 9)
		set(_toolchain "${ARGV9}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"meson"
		"${_subcomponents}"
		""
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Dependant CMake component wrapper (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV9).
## @param[in] toolchain Optional (ARGV10) BuildMaster toolchain name.
function(create_cmake_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents _dependency)
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 10)
		set(_toolchain "${ARGV10}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"cmake"
		"${_subcomponents}"
		"${_dependency}"
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Dependant Meson component wrapper (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV9).
## @param[in] toolchain Optional (ARGV10) BuildMaster toolchain name.
function(create_meson_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents _dependency)
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 10)
		set(_toolchain "${ARGV10}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"${_library_mode}"
		"meson"
		"${_subcomponents}"
		"${_dependency}"
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Header-only CMake component (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV6).
## @param[in] toolchain Optional (ARGV7) BuildMaster toolchain name.
function(create_cmake_headers_component _library_create_file _component _component_title _srcdir _builddir _options)
	if(ARGC GREATER 6)
		set(_indent_level "${ARGV6}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 7)
		set(_toolchain "${ARGV7}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"cmake"
		""
		""
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Dependant header-only CMake component (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV7).
## @param[in] toolchain Optional (ARGV8) BuildMaster toolchain name.
function(create_cmake_headers_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _dependency)
	if(ARGC GREATER 7)
		set(_indent_level "${ARGV7}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 8)
		set(_toolchain "${ARGV8}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"cmake"
		""
		"${_dependency}"
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Header-only Meson component (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV6).
## @param[in] toolchain Optional (ARGV7) BuildMaster toolchain name.
function(create_meson_headers_component _library_create_file _component _component_title _srcdir _builddir _options)
	if(ARGC GREATER 6)
		set(_indent_level "${ARGV6}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 7)
		set(_toolchain "${ARGV7}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"meson"
		""
		""
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Dependant header-only Meson component (optional indent, optional toolchain).
## @param[in] indent_level Optional (ARGV7).
## @param[in] toolchain Optional (ARGV8) BuildMaster toolchain name.
function(create_meson_headers_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _dependency)
	if(ARGC GREATER 7)
		set(_indent_level "${ARGV7}")
	else()
		set(_indent_level 0)
	endif()
	if(ARGC GREATER 8)
		set(_toolchain "${ARGV8}")
	else()
		set(_toolchain "")
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_srcdir}"
		"${_builddir}"
		"${_options}"
		"headers"
		"meson"
		""
		"${_dependency}"
		${_indent_level}
		"${_toolchain}"
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Generate a CMake fragment that renames a wrongly-named static library.
function(rename_static_library _rename_file _component _badname)
	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_BAD_PATH "${BUILDMASTER_INSTALL_LIBDIR}/${_badname}")
	library_import_static_hint(_LIBRARY_GOOD_PATH "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_RENAME_FILE "${BUILDMASTER_SCRIPTS_COMPONENTDIR}/${_badname}_rename.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_SRCDIR}/rename_static_library.cmake.in"
		"${_LIBRARY_RENAME_FILE}"
		@ONLY
	)

	set(${_rename_file} "${_LIBRARY_RENAME_FILE}" PARENT_SCOPE)
endfunction()

## @brief Generate a platform-specific bundler script for static libraries.
function(create_bundle_static_libraries _bundle_file _component _libraries)
	sanitize_for_filename(_BUNDLE_COMPONENT_SAFE "${_component}")
	library_import_static_hint(LIBRARY_PATH "${_component}")

	if(MSVC)
		set(_BUNDLE_SCRIPT_FILE "${BUILDMASTER_SCRIPTS_COMPONENTDIR}/${_BUNDLE_COMPONENT_SAFE}_bundler.bat")
		set(ADD_LIBRARIES "")
		foreach(lib IN LISTS _libraries)
			string(APPEND ADD_LIBRARIES "${lib} ")
		endforeach()
		configure_file(
			"${BUILDMASTER_COMPONENT_SRCDIR}/bundler.bat.in"
			"${_BUNDLE_SCRIPT_FILE}"
			@ONLY
		)
	elseif(APPLE)
		set(_BUNDLE_SCRIPT_FILE "${BUILDMASTER_SCRIPTS_COMPONENTDIR}/${_BUNDLE_COMPONENT_SAFE}_bundler.sh")
		set(ADD_LIBRARIES "")
		foreach(lib IN LISTS _libraries)
			string(APPEND ADD_LIBRARIES "\"${lib}\" ")
		endforeach()
		configure_file(
			"${BUILDMASTER_COMPONENT_SRCDIR}/bundler_macos.sh.in"
			"${_BUNDLE_SCRIPT_FILE}"
			@ONLY
		)
		execute_process(
			COMMAND ${ENV_RUNNER_SILENT} chmod +x "${_BUNDLE_SCRIPT_FILE}"
			RESULT_VARIABLE _chmod_result
			OUTPUT_QUIET
			ERROR_QUIET
		)
	else()
		set(_BUNDLE_SCRIPT_FILE "${BUILDMASTER_SCRIPTS_COMPONENTDIR}/${_BUNDLE_COMPONENT_SAFE}_bundler.sh")
		set(ADD_LIBRARIES "")
		foreach(lib IN LISTS _libraries)
			string(APPEND ADD_LIBRARIES "ADDLIB ${lib}\n")
		endforeach()
		configure_file(
			"${BUILDMASTER_COMPONENT_SRCDIR}/bundler.sh.in"
			"${_BUNDLE_SCRIPT_FILE}"
			@ONLY
		)
		execute_process(
			COMMAND ${ENV_RUNNER_SILENT} chmod +x "${_BUNDLE_SCRIPT_FILE}"
			RESULT_VARIABLE _chmod_result
			OUTPUT_QUIET
			ERROR_QUIET
		)
	endif()

	set(${_bundle_file} "${_BUNDLE_SCRIPT_FILE}" PARENT_SCOPE)
endfunction()
