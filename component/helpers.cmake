# Include GNUInstallDirs for standard installation directory variables
include(GNUInstallDirs)

## @brief Build a platform-correct shared-library filename for a component.
## @param[out] out_var Parent-scope variable that will receive the final
##            path.
## @param[in] lib_name Base library name without platform affixes (for
##            example: avcodec).
## @param[in] prefix_path Optional directory prefix to use instead of
##            `${BUILDMASTER_INSTALL_LIBDIR}`.
## @note On MSVC this composes an import-library name using
##       `CMAKE_IMPORT_LIBRARY_PREFIX`/`CMAKE_IMPORT_LIBRARY_SUFFIX`.
##       On other platforms it composes a shared object/DLL name using
##       `CMAKE_SHARED_LIBRARY_PREFIX`/`CMAKE_SHARED_LIBRARY_SUFFIX`.
##       The returned value is a concatenation of the chosen directory,
##       platform prefix, `lib_name` and suffix.
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
## @param[out] out_var Parent-scope variable that will receive the
##            resulting path.
## @param[in] lib_name Base library name without prefixes/suffixes.
## @param[in] prefix_path Optional directory prefix to use instead of
##            `${BUILDMASTER_INSTALL_LIBDIR}`.
## @note Uses `CMAKE_STATIC_LIBRARY_PREFIX` and
##       `CMAKE_STATIC_LIBRARY_SUFFIX` to assemble the filename and
##       prepends the chosen directory prefix.
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
## @param[out] out_var Parent-scope variable that will receive the DLL
##            path.
## @param[in] lib_name Base library name without prefixes/suffixes.
## @param[in] prefix_path Optional directory to use instead of
##            `${BUILDMASTER_INSTALL_BINDIR}`.
## @note Emits `FATAL_ERROR` on non-MSVC platforms. On MSVC the DLL
##       name is composed from `CMAKE_SHARED_LIBRARY_PREFIX` and
##       `CMAKE_SHARED_LIBRARY_SUFFIX` and placed under the chosen
##       bindir. Useful when DLLs and import libraries are in
##       different install directories.
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

## @brief Generate a per-component generator fragment (CMake) for a
##        component and declare an IMPORTED target wired to its
##        install/build stages.
## @param[out] _library_create_file Parent-scope variable that will
##            receive the generated fragment path.
## @param[in] _component Short identifier for the component used in
##            filenames and stage names.
## @param[in] _component_title Human-readable title inserted into
##            templates.
## @param[in] _srcdir Path to component source directory.
## @param[in] _builddir Path to component build directory.
## @param[in] _options List of options forwarded to stage generator
##            helpers.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _build_system `cmake` or `meson`.
## @param[in] _subcomponents List of subcomponent names (ignored for headers).
## @param[in] _dependency Optional; when non-empty selects dependant
##            templates so the generated fragment can express ordering
##            to another stage.
## @param[in] indent_level Optional numeric indentation level passed as
##            ARGV10 when present.
function(create_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _build_system _subcomponents _dependency)
	# Optional indent level
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
	else()
		set(_indent_level 0)
	endif()

	# Common variables
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
		# Header-only: no IMPORTED libs; stamp is the install OUTPUT artifact.
		set(_LIBRARY_GENERATOR_FILE "component_headers${_component_suffix}.cmake.in")
		set(_LIBRARY_COMPONENT_NAMES "")
		set(_LIBRARY_COMPONENT_FILES "${_builddir}/.buildmaster_headers_installed")
		set(_LIBRARY_COMPONENT_DLL_FILES "")
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_component (expected static, shared, or headers)")
	endif()

	if(_build_system STREQUAL "cmake")
		create_cmake_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_srcdir}" "${_builddir}" "${_options}" "${_library_mode}" "${_LIBRARY_COMPONENT_FILES}" "${_indent_level}")
	elseif(_build_system STREQUAL "meson")
		create_meson_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_srcdir}" "${_builddir}" "${_options}" "${_library_mode}" "${_LIBRARY_COMPONENT_FILES}" "${_indent_level}")
	else()
		message(FATAL_ERROR "Unknown build system '${_build_system}' in create_component")
	endif()

	# Set needed variables for template
	sanitize_for_filename(_LIBRARY_COMPONENT_SAFE "${_component}")
	set(_LIBRARY_CREATE_FILE "${BUILDMASTER_SCRIPTS_COMPONENTDIR}/${_LIBRARY_COMPONENT_SAFE}_library.cmake")

	# Expose dependency list to the template (may be empty)
	set(_LIBRARY_DEPENDENCIES "${_dependency}")

	configure_file(
		"${BUILDMASTER_COMPONENT_SRCDIR}/${_LIBRARY_GENERATOR_FILE}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()

## @brief Wrapper that calls `create_component` with `_build_system` set
##        to `cmake`.
## @param[out] _file_library Parent-scope variable that will receive
##            the generated fragment path.
## @param[in] _component Component identifier.
## @param[in] _component_title Human-readable component title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to the generator.
## @param[in] _library_mode `static` or `shared`.
## @param[in] _subcomponents List of subcomponents.
## @param[in] indent_level Optional indentation level passed as ARGV8.
function(create_cmake_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents)
	# Optional indent level
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
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
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Wrapper that calls `create_component` with `_build_system` set
##        to `meson`.
## @param[out] _file_library Parent-scope variable that will receive
##            the generated fragment path.
## @param[in] _component Component identifier.
## @param[in] _component_title Human-readable component title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to the generator.
## @param[in] _library_mode `static` or `shared`.
## @param[in] _subcomponents List of subcomponents.
## @param[in] indent_level Optional indentation level passed as ARGV8.
function(create_meson_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents)
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
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
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Wrapper that calls `create_component` with `_build_system` set
##        to `cmake` and forwards `_dependency` to select dependant
##        templates.
## @param[out] _file_library Parent-scope variable that will receive
##            the generated fragment path.
## @param[in] _component Component identifier.
## @param[in] _component_title Human-readable component title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to the generator.
## @param[in] _library_mode `static` or `shared`.
## @param[in] _subcomponents List of subcomponents.
## @param[in] _dependency Dependency name to select dependant
##            templates.
## @param[in] indent_level Optional indentation level passed as ARGV9.
function(create_cmake_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents _dependency)
	# Optional indent level
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
	else()
		set(_indent_level 0)
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
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Wrapper that calls `create_component` with `_build_system` set
##        to `meson` and forwards `_dependency` to select dependant
##        templates.
## @param[out] _file_library Parent-scope variable that will receive
##            the generated fragment path.
## @param[in] _component Component identifier.
## @param[in] _component_title Human-readable component title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to the generator.
## @param[in] _library_mode `static` or `shared`.
## @param[in] _subcomponents List of subcomponents.
## @param[in] _dependency Dependency name to select dependant
##            templates.
## @param[in] indent_level Optional indentation level passed as ARGV9.
function(create_meson_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _library_mode _subcomponents _dependency)
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
	else()
		set(_indent_level 0)
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
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Generate a CMake fragment that renames a wrongly-named static
##        library installed by a component to its canonical filename.
## @param[out] _rename_file Parent-scope variable name to receive the
##            generated script path.
## @param[in] _component Component id used to derive the canonical
##            static-library name.
## @param[in] _badname Filename currently present in the install
##            libdir that should be renamed.
## @note Constructs `_LIBRARY_BAD_PATH` as
##       `${BUILDMASTER_INSTALL_LIBDIR}/${_badname}`, computes
##       `_LIBRARY_GOOD_PATH` via `library_import_static_hint` and
##       configures `rename_static_library.cmake.in` into
##       `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` producing a fragment that
##       performs the rename using `cmake -E rename` when executed.
## @note This function only generates the fragment; callers must include
##       or install it so the rename runs as part of the component's
##       install stage. Assumes `${BUILDMASTER_INSTALL_LIBDIR}` and
##       `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` exist and are writable.
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

## @brief Generate a platform-specific bundler script that aggregates one
##        or more static library files for a component.
## @param[out] _bundle_file Parent-scope variable name that will receive
##            the resulting bundle script path.
## @param[in] _component Short component identifier used to build
##            filenames.
## @param[in] _libraries CMake list of full paths to library files to
##            include in the bundle.
## @note Produces a safe filename derived from `_component` to name the
##       script. On MSVC a Windows batch file (`*_bundler.bat`) is
##       generated where libraries are expanded into a single
##       space-separated string. On non-MSVC platforms a shell script
##       (`*_bundler.sh`) is generated with `ADDLIB <full-path>` lines
##       and the script is made executable. `_libraries` must contain
##       full paths; the function will not alter them. The generated
##       script path is exported to the parent scope via `_bundle_file`.
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
		# macOS / Apple Silicon: libtool -static (no MRI / ar -M)
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
		# Linux / GNU ar MRI script
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

## @brief Header-only CMake component (configure + build + install, INTERFACE only).
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Component id (e.g. vulkan-headers).
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory.
## @param[in] _builddir Build directory.
## @param[in] _options CMake -D options list.
## @param[in] indent_level Optional (ARGV6).
## @note Uses library mode `headers`: stamp OUTPUT, no IMPORTED archives.
function(create_cmake_headers_component _library_create_file _component _component_title _srcdir _builddir _options)
	if(ARGC GREATER 6)
		set(_indent_level "${ARGV6}")
	else()
		set(_indent_level 0)
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
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Header-only CMake component that waits on another *_install target.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Component id.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory.
## @param[in] _builddir Build directory.
## @param[in] _options CMake -D options list.
## @param[in] _dependency Install target name (e.g. other_headers_install).
## @param[in] indent_level Optional (ARGV7).
function(create_cmake_headers_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _dependency)
	if(ARGC GREATER 7)
		set(_indent_level "${ARGV7}")
	else()
		set(_indent_level 0)
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
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Header-only Meson component (configure + compile + install, INTERFACE only).
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Component id.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory.
## @param[in] _builddir Build directory.
## @param[in] _options Meson -D options list.
## @param[in] indent_level Optional (ARGV6).
function(create_meson_headers_component _library_create_file _component _component_title _srcdir _builddir _options)
	if(ARGC GREATER 6)
		set(_indent_level "${ARGV6}")
	else()
		set(_indent_level 0)
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
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## @brief Header-only Meson component that waits on another *_install target.
## @param[out] _library_create_file Parent-scope variable receiving the fragment path.
## @param[in] _component Component id.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory.
## @param[in] _builddir Build directory.
## @param[in] _options Meson -D options list.
## @param[in] _dependency Install target name (e.g. other_headers_install).
## @param[in] indent_level Optional (ARGV7).
function(create_meson_headers_dependant_component _library_create_file _component _component_title _srcdir _builddir _options _dependency)
	if(ARGC GREATER 7)
		set(_indent_level "${ARGV7}")
	else()
		set(_indent_level 0)
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
	)
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()
