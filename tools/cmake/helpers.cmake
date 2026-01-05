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
##  - _srcdir: path to the component source directory.
##  - _builddir: path to the component build directory.
##  - _options: list of CMake options to pass to the component's configure.
##  - _library_mode: either `static` or `shared` — controls template behavior.
##  - _output_libraries: one or more full paths (or a single path) to the
##                       built library/artifact(s) produced by the component.
##                       This value is exported into `_CMAKE_OUTPUT_LIBRARIES`
##                       for use inside the templates.
##  - _indent_level (optional, passed as ARGV10): number of tab characters
##                  to prepend to generated lines; when provided an
##                  `_CMAKE_INDENT_` variable is set for use inside templates.
##                  This optional argument should come after `_output_libraries`.
##
### Behaviour:
##  - Appends `_build` and `_install` to `_component` to form stage names.
##  - Sets up template variables: `_CMAKE_COMPONENT_TITLE`, `_CMAKE_SRCDIR`,
##    `_CMAKE_BUILD_DIR`, `_CMAKE_OUTPUT_LIBRARIES` and `_CMAKE_OPTIONS` (the
##    `_options` list is joined with "\n\t\t").
##  - Calls `sanitize_for_filename` to produce `_CMAKE_COMPONENT_SAFE` used
##    to create three output paths inside `${BUILDMASTER_SCRIPTS_CMAKEDIR}`:
##      * configure_<safe>.cmake
##      * build_<safe>.cmake
##      * install_<safe>.cmake
##  - Generates the three scripts from the templates in
##    `${BUILDMASTER_TOOLS_CMAKE_SRCDIR}` via `configure_file`.
##  - Exports the generated file paths to the parent scope variables named
##    by `_file_configure`, `_file_compile` and `_file_install` and exports
##    `_CMAKE_OUTPUT_LIBRARY` for use by the templates.
##
### Return / Side effects:
##  - No direct return value; results are provided through parent-scope
##    variables.
##  - The `configure_file` calls create or overwrite files under
##    `${BUILDMASTER_SCRIPTS_CMAKEDIR}` when the function runs.
##
### Note / Observación:
##  - The function calls `sanitize_for_filename(_CMAKE_COMPONENT_SAFE "${_component}")`.
##    This produces a safe filename for use in the generated script paths.
##
### Example (conceptual):
##  create_cmake_stages(cfg_file build_file install_file mylib "My Lib"
##                      /path/to/src /path/to/build "${options}"
##                      shared "/path/to/mylibname.so" 1
function(create_cmake_stages _file_configure _file_compile _file_install _component _component_title _srcdir _builddir _options _library_mode _output_libraries)
	# Optional indent level
	if(ARGC GREATER 10)
		set(_indent_level "${ARGV10}")
		string(REPEAT "\t" ${_indent_level} _CMAKE_INDENT_)
	else()
		set(_CMAKE_INDENT_ "")
	endif()

	if(${_library_mode} STREQUAL "static")
		set(_CMAKE_SHARED_MODE "OFF")
	elseif(${_library_mode} STREQUAL "shared")
		set(_CMAKE_SHARED_MODE "ON")
	else()
		message(FATAL_ERROR "Unknown library mode '${_library_mode}' in create_cmake_stages")
	endif()

	set(_CMAKE_COMPONENT_TITLE "${_component_title}")
	string(APPEND _CMAKE_STAGE_BUILD "${_component}" "_build")
	string(APPEND _CMAKE_STAGE_INSTALL "${_component}" "_install")
	set(_CMAKE_SRCDIR "${_srcdir}")
	set(_CMAKE_BUILD_DIR "${_builddir}")
	set(_CMAKE_OUTPUT_LIBRARIES "${_output_libraries}")

	list_join(_CMAKE_OPTIONS "${_options}" "\n\t\t")

	sanitize_for_filename(_CMAKE_COMPONENT_SAFE "${_component}")

	set(_CMAKE_CONFIGURE_FILE
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_configure.cmake"
	)
	set(_CMAKE_BUILD_FILE
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_build.cmake"
	)
	set(_CMAKE_INSTALL_FILE
		"${BUILDMASTER_SCRIPTS_CMAKEDIR}/${_CMAKE_COMPONENT_SAFE}_install.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_CMAKE_SRCDIR}/configure.cmake.in"
		"${_CMAKE_CONFIGURE_FILE}"
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