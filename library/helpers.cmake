# Include GNUInstallDirs for standard installation directory variables
include(GNUInstallDirs)

## library_import_hint(out_var, lib_name [, prefix_path])
##
## Construct a platform‑appropriate shared-library / import‑library filename
## and store it in the variable named by `out_var` in the parent scope.
##
## Parameters:
##  - out_var: name of the variable to set in the *parent* scope that will
##             receive the constructed full filename (the function uses
##             `set(<out_var> <value> PARENT_SCOPE)`).
##  - lib_name: base library name without prefix/suffix (for example
##              `avcodec`).
##  - prefix_path (optional): if provided as a third positional argument
##              (via ARGV2) it is used as the directory prefix. When omitted
##              the module's install libdir (`${BUILDMASTER_INSTALL_LIBDIR}`)
##              is used.
##
## Behaviour:
##  - On MSVC the function constructs an import library filename using
##    `CMAKE_IMPORT_LIBRARY_PREFIX`/`CMAKE_IMPORT_LIBRARY_SUFFIX`.
##  - On other platforms it constructs a shared library filename using
##    `CMAKE_SHARED_LIBRARY_PREFIX`/`CMAKE_SHARED_LIBRARY_SUFFIX`.
##  - The returned value is a path formed by joining the chosen prefix
##    directory with the platform library prefix, the `lib_name`, and the
##    platform suffix (the function does not attempt to normalise separators
##    beyond simple concatenation with `/`).
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
## Construct a static library filename suitable for `IMPORTED` targets and
## export it into `out_var` in the parent scope.
##
## Parameters:
##  - out_var: name of the variable to set in the parent scope with the
##             constructed filename.
##  - lib_name: base library name without prefix/suffix.
##  - prefix_path (optional): third positional argument (ARGV2). If
##             supplied it is used as the directory prefix; otherwise
##             `${BUILDMASTER_INSTALL_LIBDIR}` is used.
##
## Behaviour:
##  - Uses `CMAKE_STATIC_LIBRARY_PREFIX` and `CMAKE_STATIC_LIBRARY_SUFFIX`
##    to assemble the filename and prepends the chosen directory prefix.
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
## MSVC-only helper that constructs the expected DLL filename (located under
## an install `bin`-like directory) and writes it to `out_var` in the parent
## scope. On non-MSVC platforms this function will `FATAL_ERROR` when called.
##
## Parameters:
##  - out_var: variable name to set in parent scope with the constructed DLL path.
##  - lib_name: base library name without prefix/suffix.
##  - prefix_path (optional): third positional argument (ARGV2). If omitted
##             `${BUILDMASTER_INSTALL_BINDIR}` is used as the directory.
##
## Behaviour:
##  - Uses the shared library prefix/suffix variables to construct the DLL
##    filename and places it under the chosen `bindir` prefix.
##  - Intended to be used on Windows when the DLL and import library are in
##    different install directories.
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

## create_library(_library_create_file, _component, _component_title,
##                _src_dir, _build_dir, _options, _library_mode, _build_system [, indent_level])
##
## High-level helper that generates a per-component library generator script
## (a small CMake fragment) which defines an `IMPORTED` target and a
## dependency on the corresponding install stage.
##
## Parameters:
##  - _library_create_file: name of the variable to set in the parent scope
##                          with the resulting generated script path.
##  - _component: short identifier for the component (used in stage names
##                and as part of the filename).
##  - _component_title: human-friendly title used inside templates.
##  - _src_dir/_build_dir: source and build directory paths for the component.
##  - _options: list of options (CMake or Meson) forwarded to the underlying
##              `create_*_stages` helper.
##  - _library_mode: either `static` or `shared` — controls which
##                   generator template (`add_static_library.cmake.in` or
##                   `add_shared_library.cmake.in`) is used and which
##                   filename helper is invoked.
##  - _build_system: `cmake` or `meson` — selects the stage generator used
##                   (`create_cmake_stages` or `create_meson_stages`).
##  - indent_level (optional): passed as ARGV8/ARGV9 to control indentation
##                   inside generated templates (a numeric tab count).
##
## Behaviour:
##  - For `static` mode the function calls `library_import_static_hint`
##    to compute the expected static library filename and extracts its
##    directory/name components.
##  - For `shared` mode on MSVC both `library_dll_hint` and
##    `library_import_hint` are used (DLL + import lib); on other platforms
##    `library_import_hint` is used to compute the shared object path.
##  - The chosen generator template is configured into `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}`
##    producing a per-component `*_library.cmake` file; the path is returned
##    via the variable named by `_library_create_file` in the parent scope.
##
## Notes:
##  - The helper expects the generator templates to consume template
##    variables such as `_LIBRARY_NAME`, `_LIBRARY_SHARED_FILE`,
##    `_LIBRARY_IMPORT_FILE` etc., which are prepared by the function.
##  - The optional prefix_path argument accepted by the `library_import_*`
##    helpers may be passed by callers by supplying it as the third
##    positional argument to those helpers (internal use of ARGV2).
function(create_library _library_create_file _component _component_title _src_dir _build_dir _options _library_mode _build_system)
	# Optional indent level
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
	else()
		set(_indent_level 0)
	endif()

	string(TOLOWER "${_library_mode}" _library_mode)
	if(_library_mode STREQUAL "static")
		set(_LIBRARY_GENERATOR_FILE "add_static_library.cmake.in")
		library_import_static_hint(_LIBRARY_FILE "${_component}")
		get_filename_component(_LIBRARY_INSTALL_DIR _LIBRARY_FILE DIRECTORY)
		get_filename_component(_LIBRARY_INSTALL_FILENAME _LIBRARY_FILE NAME)
	elseif(_library_mode STREQUAL "shared")
		set(_LIBRARY_GENERATOR_FILE "add_shared_library.cmake.in")
		if(MSVC)
			library_dll_hint(_LIBRARY_DLL_FILE "${_component}")
			library_import_hint(_LIBRARY_FILE "${_component}")
		else()
			library_import_hint(_LIBRARY_FILE "${_component}")
		endif()
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_library")
	endif()

	if(_build_system STREQUAL "cmake")
		create_cmake_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_src_dir}" "${_build_dir}" "${_options}" "${_LIBRARY_FILE}" "${_indent_level}")
	elseif(_build_system STREQUAL "meson")
		create_meson_stages(_LIBRARY_CONFIGURE_FILE _LIBRARY_BUILD_FILE _LIBRARY_INSTALL_FILE "${_component}" "${_component_title}" "${_src_dir}" "${_build_dir}" "${_options}" "${_LIBRARY_FILE}" "${_indent_level}")
	else()
		message(FATAL_ERROR "Unknown build system '${_build_system}' in create_library")
	endif()

	# Set needed variables
	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	sanitize_for_filename(_LIBRARY_COMPONENT_SAFE "${_component}")
	set(_LIBRARY_CREATE_FILE "${BUILDMASTER_SCRIPTS_LIBRARY_DIR}/${_LIBRARY_COMPONENT_SAFE}_library.cmake")

	configure_file(
		"${BUILDMASTER_TOOLS_LIBRARY_SRC_DIR}/${_LIBRARY_GENERATOR_FILE}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)

	set(${_library_create_file} "${_LIBRARY_CREATE_FILE}" PARENT_SCOPE)
endfunction()

## create_cmake_library(_file_library, _component, _component_title,
##                      _src_dir, _build_dir, _options, _library_mode [, indent_level])
##
## Thin wrapper around `create_library` that selects the `cmake` build
## system. Parameters mirror `create_library` but the wrapper ensures the
## generated generator script is suitable for invoking a CMake-based build
## of the component. The resulting script path is returned in the parent
## scope variable named by `_file_library`.
##
## Notes:
##  - This function only forwards arguments to `create_library` and does
##    not change semantics; it exists for clarity in higher-level callers.
##  - `indent_level` is optional and, when provided, controls tab
##    indentation inside generated templates.
function(create_cmake_library _file_library _component _component_title _src_dir _build_dir _options _library_mode)
	# Optional indent level
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
		string(REPEAT "\t" ${_indent_level} _CMAKE_INDENT_)
	else()
		set(_CMAKE_INDENT_ "")
	endif()

	create_library(_file_library _component _component_title _src_dir _build_dir _options _library_mode "cmake" _indent_level)
endfunction()

## create_meson_library(_file_library, _component, _component_title,
##                      _src_dir, _build_dir, _options, _library_mode [, indent_level])
##
## Thin wrapper around `create_library` that selects the `meson` build
## system. Parameters mirror `create_library` but the wrapper ensures the
## generated generator script is suitable for invoking a Meson-based build
## of the component. The resulting script path is returned in the parent
## scope variable named by `_file_library`.
##
## Notes:
##  - This function only forwards arguments to `create_library` and does
##    not change semantics; it exists for clarity in higher-level callers.
##  - `indent_level` is optional and, when provided, controls tab
##    indentation inside generated templates.
function(create_meson_library _file_library _component _component_title _src_dir _build_dir _options _library_mode)
	# Optional indent level
	if(ARGC GREATER 8)
		set(_indent_level "${ARGV8}")
		string(REPEAT "\t" ${_indent_level} _CMAKE_INDENT_)
	else()
		set(_CMAKE_INDENT_ "")
	endif()

	create_library(_file_library _component _component_title _src_dir _build_dir _options _library_mode "meson" _indent_level)
endfunction()

## rename_static_library(_rename_file, _component, _badname)
##
## Generate a small CMake fragment that performs a post-build rename of an
## incorrectly named static library installed by a component.
##
## Parameters:
##  - _rename_file: name of the variable to set in the parent scope with the
##                  path to the generated rename script.
##  - _component: the component identifier used to compute the canonical
##                static library filename (this is passed to
##                `library_import_static_hint` to derive the correct name).
##  - _badname: the filename as it currently appears in the install libdir
##              that should be renamed to the canonical name.
##
## Behaviour:
##  - Constructs `_LIBRARY_BAD_PATH` pointing at `${BUILDMASTER_INSTALL_LIBDIR}/${_badname}`.
##  - Uses `library_import_static_hint` to compute `_LIBRARY_GOOD_PATH` for
##    the component's expected static library filename.
##  - Produces a CMake fragment (under `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}`)
##    from the template `rename_static_library.cmake.in` which contains a
##    `add_custom_command(... POST_BUILD)` that renames the bad file to the
##    good filename using `cmake -E rename` (the template uses
##    `ENV_CMAKE_SILENT_COMMAND`).
##  - Returns the path to the generated fragment in the variable named by
##    `_rename_file` in the parent scope.
##
## Notes:
##  - This helper only generates the rename fragment; callers must include
##    or install it where appropriate so the rename is executed as part of
##    the component's install stage.
##  - The function assumes `${BUILDMASTER_INSTALL_LIBDIR}` and
##    `${BUILDMASTER_SCRIPTS_LIBRARY_DIR}` are defined and writable.
function(rename_static_library _rename_file _component _badname)
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