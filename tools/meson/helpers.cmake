### Function: create_meson_stages
### Create setup/compile/install scripts for a Meson-built component.
##
## Parameters (positional):
##  - _file_setup: name of the variable to set in parent scope with the
##                 path to the generated Meson `*_configure.cmake` script.
##  - _file_compile: name of the variable to set in parent scope with the
##                   path to the generated Meson `*_compile.cmake` script.
##  - _file_install: name of the variable to set in parent scope with the
##                   path to the generated Meson `*_install.cmake` script.
##  - _component: simple component name (used to form stage names and
##                derive the file name).
##  - _component_title: human-friendly component title (e.g. "opus").
##  - _src_dir: path to the component source directory.
##  - _build_dir: path to the component build directory.
##  - _meson_options: list of Meson options to pass to the component's setup.
##  - _library_mode: either `static` or `shared` — controls template behavior.
##  - _output_libraries: one or more full paths (or a single path) to the
##                       built library/artifact(s) produced by the component.
##                       Exported into `_MESON_OUTPUT_LIBRARIES` for use inside
##                       the templates.
##  - _indent_level (optional, passed as ARGV9): number of tab characters
##                   to prepend to generated lines; when provided `_INDENT_`
##                   is set for use inside templates. This optional argument
##                   should come after `_output_libraries`.
##
### Behaviour:
##  - Appends `_build` and `_install` to `_component` to form stage names.
##  - Sets up template variables: `_MESON_COMPONENT_TITLE`, `_MESON_SRC_DIR`,
##    `_MESON_BUILD_DIR`, `_MESON_OUTPUT_LIBRARIES` and `_MESON_OPTIONS` (the
##    `_meson_options` list is joined with a space; the Meson setup template
##    will receive `--prefix`/`--libdir` arguments as appropriate when
##    generating the runner invocation).
##  - Calls `sanitize_for_filename` to produce `_MESON_COMPONENT_SAFE` used
##    to create three output paths inside `${BUILDMASTER_SCRIPTS_MESON_DIR}`:
##      * <safe>_configure.cmake
##      * <safe>_compile.cmake
##      * <safe>_install.cmake
##  - Generates the three scripts from the templates in
##    `${BUILDMASTER_TOOLS_MESON_SRC_DIR}` via `configure_file`.
##  - Writes the generated file paths into the parent scope variables named
##    by `_file_setup`, `_file_compile` and `_file_install` and exposes
##    `_MESON_OUTPUT_LIBRARY` for template use.
##
### Return / Side effects:
##  - No direct return value; results are provided through parent-scope
##    variables.
##  - `configure_file` calls create or overwrite files under
##    `${BUILDMASTER_SCRIPTS_MESON_DIR}` when the function runs.
##
### Example (conceptual):
##  create_meson_stages(setup_file compile_file install_file mylib "My Lib"
##                      /path/to/src /path/to/build "${meson_options}"
##                      shared "/path/to/mylibname.so" 1
function(create_meson_stages _file_setup _file_compile _file_install _component _component_title _src_dir _build_dir _meson_options _library_mode _output_libraries)
	# Optional indent level
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
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_meson_stages")
	endif()

	# Original logic
	set(_MESON_COMPONENT "${_component}")
	set(_MESON_COMPONENT_TITLE "${_component_title}")
	string(APPEND _MESON_STAGE_BUILD "${_component}" "_build")
	string(APPEND _MESON_STAGE_INSTALL "${_component}" "_install")
	set(_MESON_BUILD_DIR "${_build_dir}")
	set(_MESON_SRC_DIR "${_src_dir}")
	set(_MESON_OUTPUT_LIBRARIES "${_output_libraries}")
	# Enable LTO only on Release and if CMAKE_INTERPROCEDURAL_OPTIMIZATION is set
	if(CMAKE_BUILD_TYPE STREQUAL "Release" AND CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
		set(LTO_ENABLED "true")
	else()
		set(LTO_ENABLED "false")
	endif()

	list_join(_MESON_OPTIONS "${_meson_options}" " ")

	sanitize_for_filename(_MESON_COMPONENT_SAFE "${_component}")

	set(_MESON_SETUP_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_configure.cmake"
	)
	set(_MESON_COMPILE_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_compile.cmake"
	)
	set(_MESON_INSTALL_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/${_MESON_COMPONENT_SAFE}_install.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRC_DIR}/setup.cmake.in"
		"${_MESON_SETUP_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRC_DIR}/compile.cmake.in"
		"${_MESON_COMPILE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRC_DIR}/install.cmake.in"
		"${_MESON_INSTALL_FILE}"
		@ONLY
	)

	set(${_file_setup} "${_MESON_SETUP_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_MESON_COMPILE_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_MESON_INSTALL_FILE}" PARENT_SCOPE)
endfunction()