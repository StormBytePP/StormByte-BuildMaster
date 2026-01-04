### Function: create_cmake_stages
### Create configure/build/install scripts for a third-party component.
##
## Parameters (positional):
##  - _file_configure: name of the variable to set in parent scope with the
##                     path to the generated `configure_*.cmake` script.
##  - _file_compile: name of the variable to set in parent scope with the
##                   path to the generated `build_*.cmake` script.
##  - _file_install: name of the variable to set in parent scope with the
##                   path to the generated `install_*.cmake` script.
##  - _component: short component identifier (used to form stage names and
##                derive the file name).
##  - _component_title: human-friendly component title (e.g. "Opus Codec").
##  - _src_dir: path to the component source directory.
##  - _build_dir: path to the component build directory.
##  - _options: list of CMake options to pass to the component's configure.
##  - _output_library: full path to the built library/artifact produced by the
##                     component (exported into `_CMAKE_OUTPUT_LIBRARY` for
##                     use inside the templates).
##  - _indent_level (optional, passed as ARGV9): number of tab characters
##                  to prepend to generated lines; when provided an
##                  `_CMAKE_INDENT_` variable is set for use inside templates.
##                  This optional argument should come after `_output_library`.
##
### Behaviour:
##  - Appends `_build` and `_install` to `_component` to form stage names.
##  - Sets up template variables: `_CMAKE_COMPONENT_TITLE`, `_CMAKE_SRC_DIR`,
##    `_CMAKE_BUILD_DIR`, `_CMAKE_OUTPUT_LIBRARY` and `_CMAKE_OPTIONS` (the
##    `_options` list is joined with "\n\t\t").
##  - Calls `sanitize_for_filename` to produce `_CMAKE_COMPONENT_SAFE` used
##    to create three output paths inside `${BUILDMASTER_SCRIPTS_CMAKE_DIR}`:
##      * configure_<safe>.cmake
##      * build_<safe>.cmake
##      * install_<safe>.cmake
##  - Generates the three scripts from the templates in
##    `${BUILDMASTER_TOOLS_CMAKE_SRC_DIR}` via `configure_file`.
##  - Exports the generated file paths to the parent scope variables named
##    by `_file_configure`, `_file_compile` and `_file_install` and exports
##    `_CMAKE_OUTPUT_LIBRARY` for use by the templates.
##
### Return / Side effects:
##  - No direct return value; results are provided through parent-scope
##    variables.
##  - The `configure_file` calls create or overwrite files under
##    `${BUILDMASTER_SCRIPTS_CMAKE_DIR}` when the function runs.
##
### Note / Observación:
##  - The function calls `sanitize_for_filename(_CMAKE_COMPONENT_SAFE "${_component}")`.
##    This produces a safe filename for use in the generated script paths.
##
### Example (conceptual):
##  create_cmake_stages(cfg_file build_file install_file mylib "My Lib"
##                      /path/to/src /path/to/build "${options}"
##                      /path/to/mylibname.so 1
function(create_cmake_stages _file_configure _file_compile _file_install _component _component_title _src_dir _build_dir _options _output_libraries)
	# Optional indent level
	if(ARGC GREATER 9)
		set(_indent_level "${ARGV9}")
		string(REPEAT "\t" ${_indent_level} _CMAKE_INDENT_)
	else()
		set(_CMAKE_INDENT_ "")
	endif()

	set(_CMAKE_COMPONENT_TITLE "${_component_title}")
	string(APPEND _CMAKE_STAGE_BUILD "${_component}" "_build")
	string(APPEND _CMAKE_STAGE_INSTALL "${_component}" "_install")
	set(_CMAKE_SRC_DIR "${_src_dir}")
	set(_CMAKE_BUILD_DIR "${_build_dir}")
	set(_CMAKE_OUTPUT_LIBRARIES "${_output_libraries}")

	list_join(_CMAKE_OPTIONS "${_options}" "\n\t\t")

	sanitize_for_filename(_CMAKE_COMPONENT_SAFE "${_component}")

	set(_CMAKE_CONFIGURE_FILE
		"${BUILDMASTER_SCRIPTS_CMAKE_DIR}/${_CMAKE_COMPONENT_SAFE}_configure.cmake"
	)
	set(_CMAKE_BUILD_FILE
		"${BUILDMASTER_SCRIPTS_CMAKE_DIR}/${_CMAKE_COMPONENT_SAFE}_build.cmake"
	)
	set(_CMAKE_INSTALL_FILE
		"${BUILDMASTER_SCRIPTS_CMAKE_DIR}/${_CMAKE_COMPONENT_SAFE}_install.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRC_DIR}/configure.cmake.in"
		"${_CMAKE_CONFIGURE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRC_DIR}/build.cmake.in"
		"${_CMAKE_BUILD_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRC_DIR}/install.cmake.in"
		"${_CMAKE_INSTALL_FILE}"
		@ONLY
	)
	set(${_file_configure} "${_CMAKE_CONFIGURE_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_CMAKE_BUILD_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_CMAKE_INSTALL_FILE}" PARENT_SCOPE)
endfunction()