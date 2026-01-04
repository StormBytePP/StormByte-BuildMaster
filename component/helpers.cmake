# Include GNUInstallDirs for standard installation directory variables
include(GNUInstallDirs)

## library_import_hint(out_var, lib_name [, prefix_path])
##
## Build a platform-correct shared-library filename (or MSVC import
## library) for `lib_name` and store the full path into the parent-
## scope variable named by `out_var`.
##
## Parameters
##  - out_var: parent-scope variable name that will receive the final path.
##  - lib_name: base library name without platform affixes (e.g. avcodec).
##  - prefix_path (optional): directory prefix to use instead of
##             `${BUILDMASTER_INSTALL_LIBDIR}`.
##
## Behavior
##  - On MSVC this composes an import-library name using
##    `CMAKE_IMPORT_LIBRARY_PREFIX`/`CMAKE_IMPORT_LIBRARY_SUFFIX`.
##  - On other platforms it composes a shared object / DLL name using
##    `CMAKE_SHARED_LIBRARY_PREFIX`/`CMAKE_SHARED_LIBRARY_SUFFIX`.
##  - The returned value is a simple concatenation of the chosen
##    directory, platform prefix, `lib_name`, and suffix.
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

## library_import_static_hint(out_var, lib_name [, prefix_path])
##
## Compose the canonical static library filename for `lib_name` and
## set the resulting full path into the parent-scope variable `out_var`.
##
## Parameters
##  - out_var: parent-scope variable name to receive the resulting path.
##  - lib_name: base library name without prefixes/suffixes.
##  - prefix_path (optional): directory prefix to use instead of
##             `${BUILDMASTER_INSTALL_LIBDIR}`.
##
## Behavior
##  - Uses `CMAKE_STATIC_LIBRARY_PREFIX` and
##    `CMAKE_STATIC_LIBRARY_SUFFIX` to assemble the filename and
##    prepends the chosen directory prefix.
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

## library_dll_hint(out_var, lib_name [, prefix_path])
##
## MSVC-only helper: build the DLL filename for `lib_name` and write the
## full path into the parent-scope variable `out_var`.
##
## Parameters
##  - out_var: parent-scope variable name to receive the DLL path.
##  - lib_name: base library name without prefixes/suffixes.
##  - prefix_path (optional): directory to use instead of
##             `${BUILDMASTER_INSTALL_BINDIR}`.
##
## Behavior
##  - This helper emits a `FATAL_ERROR` when used on non-MSVC
##    platforms. On MSVC it composes the DLL name from
##    `CMAKE_SHARED_LIBRARY_PREFIX`/`CMAKE_SHARED_LIBRARY_SUFFIX` and
##    places it under the chosen bindir. Intended for cases where DLLs
##    and import libraries live in different install directories.
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

## create_component(_library_create_file, _component, _component_title,
##                  _src_dir, _build_dir, _options, _library_mode,
##                  _build_system, _subcomponents, _dependency [, indent_level])
##
## Generate a per-component generator fragment (CMake) which declares an
## `IMPORTED` target and wires it to the component's install/build stages.
## The path to the generated fragment is written into the parent-scope
## variable named by `_library_create_file`.
##
## Parameters
##  - _library_create_file: parent-scope variable name that will receive
##                         the generated fragment path.
##  - _component: short identifier for the component (used in filenames
##                and stage names).
##  - _component_title: human-readable title inserted into templates.
##  - _src_dir/_build_dir: component source and build directory paths.
##  - _options: list of options forwarded to stage generator helpers.
##  - _library_mode: `static` or `shared` — chooses templates and filename helpers.
##  - _build_system: `cmake` or `meson` — selects which stage generator helper to call.
##  - _subcomponents: list of subcomponent names referenced by templates.
##  - _dependency: (may be empty) when non-empty selects alternate "dependant"
##    templates so the generated fragment can express ordering to another stage.
##  - indent_level (optional): numeric indentation level; passed as the
##    11th positional argument (ARGV10) when present.
##
## Behavior
##  - In `static` mode the helper computes static-library filenames via
##    `library_import_static_hint`. In `shared` mode it computes import
##    library names and (on MSVC) DLL names.
##  - When `_dependency` is non-empty the helper selects "dependant"
##    generator templates so the generated fragment can depend on another
##    staged target.
##  - The configured template is written into `${BUILDMASTER_SCRIPTS_COMPONENT_DIR}`
##    and the resulting path is returned via the variable named by
##    `_library_create_file` in the parent scope.
##
## Notes
##  - Templates expect variables such as `_LIBRARY_NAME`,
##    `_LIBRARY_SHARED_FILE`, and `_LIBRARY_IMPORT_FILE` to be prepared
##    by this helper before `configure_file` is invoked.
function(create_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _build_system _subcomponents _dependency)
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
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_library")
	endif()

	if(_build_system STREQUAL "cmake")
		create_cmake_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_src_dir}" "${_build_dir}" "${_options}" "${_library_mode}" "${_LIBRARY_COMPONENT_FILES}" "${_indent_level}")
	elseif(_build_system STREQUAL "meson")
		create_meson_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_src_dir}" "${_build_dir}" "${_options}" "${_library_mode}" "${_LIBRARY_COMPONENT_FILES}" "${_indent_level}")
	else()
		message(FATAL_ERROR "Unknown build system '${_build_system}' in create_library")
	endif()

	# Set needed variables for template
	sanitize_for_filename(_LIBRARY_COMPONENT_SAFE "${_component}")
	set(_LIBRARY_CREATE_FILE "${BUILDMASTER_SCRIPTS_COMPONENT_DIR}/${_LIBRARY_COMPONENT_SAFE}_library.cmake")

	# Expose dependency list to the template (may be empty)
	set(_LIBRARY_DEPENDENCIES "${_dependency}")

	configure_file(
		"${BUILDMASTER_COMPONENT_SRC_DIR}/${_LIBRARY_GENERATOR_FILE}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()

## create_cmake_component(_file_library, _component, _component_title,
##                       _src_dir, _build_dir, _options, _library_mode, _subcomponents [, indent_level])
##
## Wrapper that calls `create_component` with `_build_system` set to
## `cmake`. Its parameters are the same order as `create_component` but
## `_subcomponents` is passed at the eighth position. `indent_level` is
## optional and when present must be the ninth positional argument.
##
## The generated fragment path is returned via the parent-scope variable
## named by `_file_library` (the wrapper re-exposes that variable into
## the caller scope).
function(create_cmake_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _subcomponents)
	# Optional indent level
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
	endif()

	# Llamamos a create_component, que deja el resultado en *este* scope
	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_src_dir}"
		"${_build_dir}"
		"${_options}"
		"${_library_mode}"
		"cmake"
		"${_subcomponents}"
		""
		${_indent_level}
	)

	# Reexpone la variable al scope del llamador real
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## create_meson_component(_file_library, _component, _component_title,
##                       _src_dir, _build_dir, _options, _library_mode, _subcomponents [, indent_level])
##
## Wrapper that calls `create_component` with `_build_system` set to
## `meson`. Its parameters follow the same ordering as
## `create_cmake_component`: `_subcomponents` is the eighth argument and
## `indent_level` is an optional ninth positional argument.
##}
## The generated fragment path is returned via the parent-scope variable
## named by `_file_library` (the wrapper re-exposes that variable into
## the caller scope).
function(create_meson_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _subcomponents)
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_src_dir}"
		"${_build_dir}"
		"${_options}"
		"${_library_mode}"
		"meson"
		"${_subcomponents}"
		""
		${_indent_level}
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## create_cmake_dependant_component(_file_library, _component, _component_title,
##                                  _src_dir, _build_dir, _options, _library_mode,
##                                  _subcomponents, _dependency [, indent_level])
##
## Wrapper that calls `create_component` with `_build_system` set to
## `cmake` and forwards `_dependency` (required positional argument)
## which selects dependant templates. `indent_level` is optional and,
## when present, must be provided as the 10th positional argument.
##
## The generated fragment path is returned in the parent-scope variable
## named by `_file_library` and is re-exposed into the caller's scope.
function(create_cmake_dependant_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _subcomponents _dependency)
	# Optional indent level
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
	else()
		set(_indent_level 0)
	endif()

	# Llamamos a create_component, que deja el resultado en *este* scope
	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_src_dir}"
		"${_build_dir}"
		"${_options}"
		"${_library_mode}"
		"cmake"
		"${_subcomponents}"
		"${_dependency}"
		${_indent_level}
	)

	# Reexpone la variable al scope del llamador real
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## create_meson_dependant_component(_file_library, _component, _component_title,
##                                   _src_dir, _build_dir, _options, _library_mode,
##                                   _subcomponents, _dependency [, indent_level])
##
## Wrapper that calls `create_component` with `_build_system` set to
## `meson` and forwards `_dependency` (required positional argument)
## which selects dependant templates. `indent_level` is optional and,
## when present, must be provided as the 10th positional argument.
##
## The generated fragment path is returned in the parent-scope variable
## named by `_file_library` and is re-exposed into the caller's scope.
function(create_meson_dependant_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _subcomponents _dependency)
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
	else()
		set(_indent_level 0)
	endif()

	create_component(
		${_library_create_file}
		"${_component}"
		"${_component_title}"
		"${_src_dir}"
		"${_build_dir}"
		"${_options}"
		"${_library_mode}"
		"meson"
		"${_subcomponents}"
		"${_dependency}"
		${_indent_level}
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## rename_static_library(_rename_file, _component, _badname)
##
## Generate a small CMake fragment that renames a wrongly-named static
## library installed by a component to the canonical filename. The path
## to the generated fragment is returned in the parent-scope variable
## named by `_rename_file`.
##
## Parameters
##  - _rename_file: parent-scope variable name to receive the generated script path.
##  - _component: component id used to derive the canonical static-library name.
##  - _badname: filename currently present in the install libdir that should be renamed.
##
## Behavior
##  - Constructs `_LIBRARY_BAD_PATH` as `${BUILDMASTER_INSTALL_LIBDIR}/${_badname}`.
##  - Uses `library_import_static_hint` to compute `_LIBRARY_GOOD_PATH`.
##  - Configures `rename_static_library.cmake.in` into
##    `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}`, producing a fragment that
##    performs the rename using `cmake -E rename` when executed.
##
## Notes
##  - This function only generates the fragment; callers must include
##    or install it where appropriate so the rename runs as part of the
##    component's install stage.
##  - Assumes `${BUILDMASTER_INSTALL_LIBDIR}` and
##    `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` exist and are writable.
function(rename_static_library _rename_file _component _badname)
	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_BAD_PATH "${BUILDMASTER_INSTALL_LIBDIR}/${_badname}")
	library_import_static_hint(_LIBRARY_GOOD_PATH "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_RENAME_FILE "${BUILDMASTER_SCRIPTS_COMPONENT_DIR}/${_badname}_rename.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_SRC_DIR}/rename_static_library.cmake.in"
		"${_LIBRARY_RENAME_FILE}"
		@ONLY
	)

	set(${_rename_file} "${_LIBRARY_RENAME_FILE}" PARENT_SCOPE)
endfunction()

## create_bundle_static_libraries(_bundle_file, _component, _libraries)
##
## Generate a platform-specific "bundler" script that aggregates one or
## more static library files for a component. The function writes the
## generated script under `${BUILDMASTER_SCRIPTS_COMPONENT_DIR}` and
## returns its path via the parent-scope variable named by
## `_bundle_file`.
##
## Parameters
##  - _bundle_file: parent-scope variable name that will receive the
##                  resulting bundle script path.
##  - _component: short component identifier used to build filenames.
##  - _libraries: CMake list of full paths to library files to include in the bundle.
##
## Behavior
##  - Produces a safe filename derived from `_component` to name the script.
##  - On MSVC a Windows batch file (`*_bundler.bat`) is generated where
##    the provided full-path libraries are expanded into a single
##    space-separated string consumed by the template.
##  - On non-MSVC platforms a shell script (`*_bundler.sh`) is
##    generated which contains `ADDLIB <full-path>` lines for each
##    library; the script is made executable (`chmod +x`).
##  - The configured script is created from the templates
##    `bundler.bat.in` or `bundler.sh.in` located in
##    `${BUILDMASTER_COMPONENT_SRC_DIR}`.
##
## Notes
##  - `_libraries` must contain full paths (absolute or relative) to the
##    actual library files; the function will not prefix or alter them.
##  - The path to the generated script is exported to the parent scope
##    via the variable named by `_bundle_file`.
function(create_bundle_static_libraries _bundle_file _component _libraries)
	# Generate safe filename
	sanitize_for_filename(_BUNDLE_COMPONENT_SAFE "${_component}")

	# Compute output path
	library_import_static_hint(LIBRARY_PATH "${_component}")

	# Configure bundler script
	if(MSVC)
		set(_BUNDLE_SCRIPT_FILE "${BUILDMASTER_SCRIPTS_COMPONENT_DIR}/${_BUNDLE_COMPONENT_SAFE}_bundler.bat")
		# For MSVC we expand the list into a space-separated string
		set(ADD_LIBRARIES "")
		foreach(lib IN LISTS _libraries)
			string(APPEND ADD_LIBRARIES "${lib} ")
		endforeach()
		configure_file(
			"${BUILDMASTER_COMPONENT_SRC_DIR}/bundler.bat.in"
			"${_BUNDLE_SCRIPT_FILE}"
			@ONLY
		)
	else()
		set(_BUNDLE_SCRIPT_FILE "${BUILDMASTER_SCRIPTS_COMPONENT_DIR}/${_BUNDLE_COMPONENT_SAFE}_bundler.sh")
		# In linux we expect ADDLIB lib\n
		set(ADD_LIBRARIES "")
		foreach(lib IN LISTS _libraries)
			string(APPEND ADD_LIBRARIES "ADDLIB ${lib}
") # Real line break
		endforeach()
		configure_file(
			"${BUILDMASTER_COMPONENT_SRC_DIR}/bundler.sh.in"
			"${_BUNDLE_SCRIPT_FILE}"
			@ONLY
		)

		# Ensure the generated runner has execute permissions so it can be
		# invoked directly by execute_process(). Some platforms require the
		# executable bit even when a shebang is present.
		execute_process(
			COMMAND ${CMAKE_COMMAND} -E chmod 0755 "${_BUNDLE_SCRIPT_FILE}"
			RESULT_VARIABLE _chmod_result
			OUTPUT_QUIET
			ERROR_QUIET
		)
	endif()

	# Set output variables
	set(${_bundle_file} "${_BUNDLE_LIBRARY_PATH}" PARENT_SCOPE)
endfunction()