###
## Function: create_meson_setup_file
### Generates a Meson setup CMake script for a specified component.
##
## Parameters:
##  - _file: name of the variable to set in parent scope with the path to
##           the generated setup script.
##  - _component: simple name of the component (e.g. "ogg", "opus").
##  - _src_dir: path to the component's source directory.
##  - _build_dir: path to the component's build directory.
##  - _install_prefix: installation prefix to pass to Meson.
##  - _meson_options: list of Meson options to pass to the component's setup.
##  - _indent_level (optional): number of tab characters to prepend to
##                              generated lines inside the setup script.
##                              Defaults to no indentation when omitted.
##
### Behaviour:
##  - The function generates a Meson setup CMake script from the template
##    `setup.cmake.in` located in the same directory as this helper.cmake.
##  - The generated script is placed in the bootstrap CMake binary directory
##    (`${CMAKE_BINARY_DIR}`) with a name derived from the component name.
##  - The generated script sets up the component's build using the provided
##    source/build directories and options.
##  - When `_indent_level` is provided, the variable `_INDENT_` inside the
##    template will contain that number of tab characters (`\t`), allowing
##    indentation of emitted commands. When omitted, `_INDENT_` is empty.
###
function(create_meson_setup_file _file _component _src_dir _build_dir _install_prefix _meson_options)
	# Optional indent level
	if(ARGC GREATER 6)
		set(_indent_level "${ARGV6}")
		string(REPEAT "\t" ${_indent_level} _INDENT_)
	else()
		set(_INDENT_ "")
	endif()

	# Original logic
	set(_MESON_COMPONENT "${_component}")
	set(_MESON_BUILD_DIR "${_build_dir}")
	set(_MESON_SRC_DIR "${_src_dir}")

	list_join(_MESON_OPTIONS "${_meson_options}" " ")

	string(CONCAT
		_MESON_OPTIONS
		"--prefix=${_install_prefix} "
		"--libdir=${CMAKE_INSTALL_LIBDIR} "
		"-Dbuildtype=${CMAKE_BUILD_TYPE_LOWERCASE} "
		"${_MESON_OPTIONS}"
	)

	sanitize_for_filename(_MESON_COMPONENT_SAFE "${_MESON_COMPONENT}")

	set(_MESON_SETUP_FILE
		"${BUILDMASTER_SCRIPTS_MESON_DIR}/meson_configure_${_MESON_COMPONENT_SAFE}.cmake"
	)

	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRC_DIR}/setup.cmake.in"
		"${_MESON_SETUP_FILE}"
		@ONLY
	)

	set(${_file} "${_MESON_SETUP_FILE}" PARENT_SCOPE)
endfunction()