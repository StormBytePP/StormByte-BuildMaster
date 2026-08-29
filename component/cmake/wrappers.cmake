# =============================================================================
# component/cmake/wrappers.cmake — public CMake component factories
# =============================================================================

## @brief Whether `val` is a library mode token.
## @param[in]  val     Raw argument.
## @param[out] out_var Parent-scope TRUE/FALSE.
function(_buildmaster_is_library_mode val out_var)
	string(TOLOWER "${val}" _v)
	if(_v STREQUAL "static" OR _v STREQUAL "shared" OR _v STREQUAL "headers")
		set(${out_var} TRUE PARENT_SCOPE)
	else()
		set(${out_var} FALSE PARENT_SCOPE)
	endif()
endfunction()

## @brief Register a CMake-backed component (INTERFACE `<id>` exists on return).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Deprecated in 2.0.x. Omit for 2.1-style:
##            `id title srcdir options mode produced [optstr]`.
##            Legacy: `id title srcdir builddir options mode produced [optstr]`.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Ignored for headers mode.
## @param[in] options_string Optional (last argument) "KEY=value;…" string.
##            See create_component for supported keys.
## @note Mode token (`static`/`shared`/`headers`) selects the arity:
##       6/7 without a path in the builddir slot = 2.1 (BuildMaster path,
##       no WARNING). 7/8 with a path before options = 2.0 (WARNING;
##       removed in 2.1.x). Ambiguous 7-arg where both slots look like
##       mode is treated as 2.0.
## @note 2.1.x drops the explicit builddir. There is no public getter for
##       the assigned directory yet; that is why 2.0.x still accepts the
##       legacy slot.
## @note Delegates to create_component. Stages and the fragment run at
##       deferred finalize. No fragment path. No include() is required.
function(create_cmake_component _component _component_title _srcdir)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_cmake_component")

	set(_builddir "")
	set(_options "")
	set(_library_mode "")
	set(_produced "")
	set(_options_string "")
	set(_legacy FALSE)

	if(ARGC LESS 6 OR ARGC GREATER 8)
		buildmaster_message(COMPONENT FATAL
			"create_cmake_component: expected 6–8 arguments (2.1: id title srcdir options mode produced [optstr]; legacy: id title srcdir builddir options mode produced [optstr])")
	endif()

	if(ARGC EQUAL 6)
		set(_options "${ARGV3}")
		set(_library_mode "${ARGV4}")
		set(_produced "${ARGV5}")
	elseif(ARGC EQUAL 8)
		set(_legacy TRUE)
		set(_builddir "${ARGV3}")
		set(_options "${ARGV4}")
		set(_library_mode "${ARGV5}")
		set(_produced "${ARGV6}")
		set(_options_string "${ARGV7}")
	else()
		_buildmaster_is_library_mode("${ARGV4}" _m21)
		_buildmaster_is_library_mode("${ARGV5}" _m20)
		if(_m21 AND NOT _m20)
			set(_options "${ARGV3}")
			set(_library_mode "${ARGV4}")
			set(_produced "${ARGV5}")
			set(_options_string "${ARGV6}")
		else()
			set(_legacy TRUE)
			set(_builddir "${ARGV3}")
			set(_options "${ARGV4}")
			set(_library_mode "${ARGV5}")
			set(_produced "${ARGV6}")
		endif()
	endif()

	if(_legacy)
		buildmaster_message(COMPONENT WARNING
			"create_cmake_component('${_component}'): explicit build directory is deprecated and will be removed in BuildMaster 2.1.x (BuildMaster will assign the directory). There is no public getter for that path yet.")
	else()
		_buildmaster_component_builddir(_builddir "${_component}")
	endif()

	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "${_library_mode}" "cmake" "${_produced}"
		"${_options_string}"
	)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_cmake_component")
endfunction()

## @brief Register a header-only CMake component (INTERFACE `<id>` on return).
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Deprecated in 2.0.x. 2.1-style: `id title srcdir
##            options [optstr]` (4 or 5 args). Legacy: `id title srcdir
##            builddir options [optstr]` (5 or 6 args).
## @note 5 arguments are always the legacy form (existing callers). 2.1
##       plus optstr is 4 args without optstr, or wait for 2.1.x.
## @note Same deprecation as create_cmake_component: no public builddir
##       getter yet.
function(create_cmake_headers_component _component _component_title _srcdir)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_cmake_headers_component")

	set(_builddir "")
	set(_options "")
	set(_options_string "")
	set(_legacy FALSE)

	if(ARGC LESS 4 OR ARGC GREATER 6)
		buildmaster_message(COMPONENT FATAL
			"create_cmake_headers_component: expected 4–6 arguments (2.1: id title srcdir options [optstr]; legacy: id title srcdir builddir options [optstr])")
	endif()

	if(ARGC EQUAL 4)
		set(_options "${ARGV3}")
	elseif(ARGC EQUAL 6)
		set(_legacy TRUE)
		set(_builddir "${ARGV3}")
		set(_options "${ARGV4}")
		set(_options_string "${ARGV5}")
	else()
		set(_legacy TRUE)
		set(_builddir "${ARGV3}")
		set(_options "${ARGV4}")
	endif()

	if(_legacy)
		buildmaster_message(COMPONENT WARNING
			"create_cmake_headers_component('${_component}'): explicit build directory is deprecated and will be removed in BuildMaster 2.1.x (BuildMaster will assign the directory). There is no public getter for that path yet.")
	else()
		_buildmaster_component_builddir(_builddir "${_component}")
	endif()

	create_component(
		"${_component}" "${_component_title}" "${_srcdir}" "${_builddir}"
		"${_options}" "headers" "cmake" ""
		"${_options_string}"
	)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_cmake_headers_component")
endfunction()
