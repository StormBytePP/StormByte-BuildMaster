## @brief Create setup/compile/install scripts for a Meson-built component.
## @param[out] _file_setup Name of the variable to set in parent scope
##            with the generated Meson `*_configure.cmake` script path.
## @param[out] _file_compile Name of the variable to set in parent scope
##            with the generated Meson `*_compile.cmake` script path.
## @param[out] _file_install Name of the variable to set in parent scope
##            with the generated Meson `*_install.cmake` script path.
## @param[in] _component Simple component name used to form stage names
##            and derive the file name.
## @param[in] _component_title Human-friendly component title.
## @param[in] _srcdir Path to the component source directory.
## @param[in] _builddir Path to the component build directory.
## @param[in] _meson_options List of Meson options to pass to the
##            component's setup.
## @param[in] _library_mode Either `static` or `shared` — controls
##            template behaviour.
## @param[in] _output_libraries One or more full paths to the built
##            library/artifact(s) produced by the component; exported as
##            `_MESON_OUTPUT_LIBRARIES` for template use.
## @param[in] _indent_level Optional (passed as ARGV9) number of tab
##            characters to prepend to generated lines; when provided
##            `_INDENT_` is set for template use.
## @note Appends `_build` and `_install` to `_component` to form stage
##       names; sets template variables such as `_MESON_COMPONENT_TITLE`,
##       `_MESON_SRCDIR`, `_MESON_BUILD_DIR`, `_MESON_OUTPUT_LIBRARIES` and
##       `_MESON_OPTIONS` (the `_meson_options` list is joined with a
##       space). Calls `sanitize_for_filename` to produce
##       `_MESON_COMPONENT_SAFE` used to create output paths inside
##       `${BUILDMASTER_SCRIPTS_MESON_DIR}` and generates three scripts
##       from templates in `${BUILDMASTER_TOOLS_MESON_SRCDIR}` via
##       `configure_file`.
## @return Results are provided through parent-scope variables; the
##         `configure_file` calls create or overwrite files under
##         `${BUILDMASTER_SCRIPTS_MESON_DIR}`.
## @example
##   create_meson_stages(setup_file compile_file install_file mylib "My Lib"
##                       /path/to/src /path/to/build "${meson_options}"
##                       shared "/path/to/mylibname.so" 1
function(create_meson_stages _file_setup _file_compile _file_install _component _component_title _srcdir _builddir _meson_options _library_mode _output_libraries)
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
	set(_MESON_BUILD_DIR "${_builddir}")
	set(_MESON_SRCDIR "${_srcdir}")
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
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/setup.cmake.in"
		"${_MESON_SETUP_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/compile.cmake.in"
		"${_MESON_COMPILE_FILE}"
		@ONLY
	)
	configure_file(
		"${BUILDMASTER_TOOLS_MESON_SRCDIR}/install.cmake.in"
		"${_MESON_INSTALL_FILE}"
		@ONLY
	)

	set(${_file_setup} "${_MESON_SETUP_FILE}" PARENT_SCOPE)
	set(${_file_compile} "${_MESON_COMPILE_FILE}" PARENT_SCOPE)
	set(${_file_install} "${_MESON_INSTALL_FILE}" PARENT_SCOPE)
endfunction()