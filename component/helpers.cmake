# Include GNUInstallDirs for standard installation directory variables
include(GNUInstallDirs)

## library_import_hint(out_var, lib_name [, prefix_path])
##
## Assemble a platform-correct shared-library (or import-library on
## MSVC) filename and write the full path into the named parent-scope
## variable `out_var`.
##
## Parameters
##  - out_var: variable name (in the parent scope) that will receive the
##             resulting full path (set with `PARENT_SCOPE`).
##  - lib_name: library base name without platform prefixes/suffixes.
##  - prefix_path (optional): directory to prepend; when omitted the
##             helper uses `${BUILDMASTER_INSTALL_LIBDIR}`.
##
## Behavior
##  - On MSVC the name is formed from `CMAKE_IMPORT_LIBRARY_PREFIX`
##    and `CMAKE_IMPORT_LIBRARY_SUFFIX` (import library). On other
##    platforms it uses `CMAKE_SHARED_LIBRARY_PREFIX` and
##    `CMAKE_SHARED_LIBRARY_SUFFIX` (shared object / DLL name).
##  - The helper does not normalise path separators beyond simple
##    concatenation: it yields `<prefix>/<prefix_symbol><lib_name><suffix>`.
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
## Build the canonical static-library filename for `lib_name` and set the
## full path into the parent-scope variable `out_var`.
##
## Parameters
##  - out_var: parent-scope variable name to receive the constructed path.
##  - lib_name: library base name (no prefix/suffix).
##  - prefix_path (optional): directory to use instead of
##             `${BUILDMASTER_INSTALL_LIBDIR}`.
##
## Behavior
##  - Uses `CMAKE_STATIC_LIBRARY_PREFIX` and `CMAKE_STATIC_LIBRARY_SUFFIX`
##    to compose the filename and places it under the chosen prefix.
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
## MSVC-only: construct the expected DLL filename for `lib_name` and set
## the resulting path into the parent-scope variable `out_var`.
##
## Parameters
##  - out_var: parent-scope variable name to receive the DLL path.
##  - lib_name: base library name without platform-specific affixes.
##  - prefix_path (optional): directory to use instead of
##             `${BUILDMASTER_INSTALL_BINDIR}`.
##
## Behavior
##  - Fails with `FATAL_ERROR` when invoked on non-MSVC platforms.
##  - On MSVC it uses `CMAKE_SHARED_LIBRARY_PREFIX`/`CMAKE_SHARED_LIBRARY_SUFFIX`
##    and places the DLL under the chosen bindir. Useful when import
##    libraries and DLLs are installed to different directories.
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
##                  _src_dir, _build_dir, _options, _library_mode, _build_system [, indent_level])
##
## Generate a per-component CMake fragment that declares an `IMPORTED`
## library target and wires it to the component's install stage. The
## function writes the generated fragment path into the parent-scope
## variable named by `_library_create_file`.
##
## Parameters
##  - _library_create_file: parent-scope variable name to receive the
##                         generated script path.
##  - _component: short component id used for stage names and filenames.
##  - _component_title: human-readable title inserted into templates.
##  - _src_dir/_build_dir: component source and build directory paths.
##  - _options: list of build options forwarded to stage generators.
##  - _library_mode: `static` or `shared`, selects templates and filename helpers.
##  - _build_system: `cmake` or `meson`, selects which stage generator to call.
##  - indent_level (optional): numeric indentation level forwarded to templates.
##  - _subcomponents: list of subcomponent names whose files are referenced.
##
## Behavior
##  - In `static` mode the helper computes expected static-library paths
##    (via `library_import_static_hint`) and exposes them to the template.
##  - In `shared` mode it computes import-library paths (and on MSVC also
##    DLL paths) so templates can reference the correct files.
##  - The chosen generator template (`component_static.cmake.in` or
##    `component_shared.cmake.in`) is configured into
##    `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` producing the per-component
##    fragment; its path is returned in the variable named by
##    `_library_create_file`.
##
## Notes
##  - Templates expect variables such as `_LIBRARY_NAME`,
##    `_LIBRARY_SHARED_FILE`, and `_LIBRARY_IMPORT_FILE` to be set by
##    this helper before configuration.
function(create_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _build_system _subcomponents)
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
	if(_library_mode STREQUAL "static")
		set(_LIBRARY_GENERATOR_FILE "component_static.cmake.in")
		set(_LIBRARY_COMPONENT_NAMES "")
		set(_LIBRARY_COMPONENT_FILES "")
		foreach(_subcomponent IN LISTS _subcomponents)
			list(APPEND _LIBRARY_COMPONENT_NAMES "${_subcomponent}_component")
			library_import_static_hint(_LIBRARY_FILE_SUB "${_subcomponent}")
			list(APPEND _LIBRARY_COMPONENT_FILES "${_LIBRARY_FILE_SUB}")
		endforeach()
	elseif(_library_mode STREQUAL "shared")
		set(_LIBRARY_GENERATOR_FILE "component_shared.cmake.in")
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
		create_cmake_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_src_dir}" "${_build_dir}" "${_options}" "${_LIBRARY_COMPONENT_FILES}" "${_indent_level}")
	elseif(_build_system STREQUAL "meson")
		create_meson_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_src_dir}" "${_build_dir}" "${_options}" "${_LIBRARY_COMPONENT_FILES}" "${_indent_level}")
	else()
		message(FATAL_ERROR "Unknown build system '${_build_system}' in create_library")
	endif()

	# Set needed variables for template
	sanitize_for_filename(_LIBRARY_COMPONENT_SAFE "${_component}")
	set(_LIBRARY_CREATE_FILE "${BUILDMASTER_SCRIPTS_COMPONENT_DIR}/${_LIBRARY_COMPONENT_SAFE}_library.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_SRC_DIR}/${_LIBRARY_GENERATOR_FILE}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()

## create_cmake_component(_file_library, _component, _component_title,
##                       _src_dir, _build_dir, _options, _library_mode [, indent_level])
##
## Convenience wrapper that calls `create_component` with `_build_system`
## fixed to `cmake`. Returns the generated fragment path in the parent
## scope variable named by `_file_library`.
##
## Notes
##  - Semantics and parameters are identical to `create_component`; this
##    wrapper exists to make caller intent explicit.
function(create_cmake_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _subcomponents)
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
		${_indent_level}
	)

	# Reexpone la variable al scope del llamador real
	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## create_meson_component(_file_library, _component, _component_title,
##                       _src_dir, _build_dir, _options, _library_mode [, indent_level])
##
## Convenience wrapper that calls `create_component` with `_build_system`
## fixed to `meson`. Returns the generated fragment path in the parent
## scope variable named by `_file_library`.
##
## Notes
##  - Semantics and parameters match `create_component`; this wrapper is
##    provided to clarify that the generated fragment targets a Meson build.
function(create_meson_component _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _subcomponents)
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
		${_indent_level}
	)

	set(${_library_create_file} "${${_library_create_file}}" PARENT_SCOPE)
endfunction()

## rename_static_library(_rename_file, _component, _badname)
##
## Generate a small CMake fragment that renames an incorrectly named
## static library file installed by a component to the canonical name.
## The path to the generated rename fragment is returned in the parent
## scope variable named by `_rename_file`.
##
## Parameters
##  - _rename_file: parent-scope variable name to receive the generated script path.
##  - _component: component id used to derive the canonical static-library name.
##  - _badname: filename currently present in the install libdir that should be renamed.
##
## Behavior
##  - Computes `_LIBRARY_BAD_PATH` as `${BUILDMASTER_INSTALL_LIBDIR}/${_badname}`.
##  - Computes the expected canonical path via `library_import_static_hint`.
##  - Configures `rename_static_library.cmake.in` into
##    `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` producing a fragment which performs
##    the rename (via `cmake -E rename`) when executed.
##
## Notes
##  - This helper only generates the fragment; callers must ensure the
##    fragment is executed (for example by including it in the install stage).
##  - The function assumes `${BUILDMASTER_INSTALL_LIBDIR}` and
##    `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` exist and are writable.
function(rename_static_library _rename_file _component _badname)
	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_BAD_PATH "${BUILDMASTER_INSTALL_LIBDIR}/${_badname}")
	library_import_static_hint(_LIBRARY_GOOD_PATH "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_RENAME_FILE "${BUILDMASTER_SCRIPTS_LIBRARY_DIR}/${_badname}_rename.cmake")

	configure_file(
		"${BUILDMASTER_TOOLS_LIBRARY_SRC_DIR}/rename_static_library.cmake.in"
		"${_LIBRARY_RENAME_FILE}"
		@ONLY
	)

	set(${_rename_file} "${_LIBRARY_RENAME_FILE}" PARENT_SCOPE)
endfunction()