# =============================================================================
# component/factory.cmake — backend-agnostic public factory
# =============================================================================

## @brief Detect cmake vs meson from files in `srcdir`.
## @param[in]  srcdir  Component source directory.
## @param[out] out_var Parent-scope `cmake` or `meson`.
## @note Exactly one of `CMakeLists.txt` / `meson.build`. Both or neither
##       is FATAL. No recursion into subdirectories.
function(_bm_detect_build_system srcdir out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_detect_build_system")
	if("${srcdir}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_detect_build_system: empty source directory")
	endif()
	if(NOT IS_DIRECTORY "${srcdir}")
		_bm_log_message(COMPONENT FATAL
			"_bm_detect_build_system: '${srcdir}' is not a directory")
	endif()

	set(_cmake FALSE)
	set(_meson FALSE)
	if(EXISTS "${srcdir}/CMakeLists.txt")
		set(_cmake TRUE)
	endif()
	if(EXISTS "${srcdir}/meson.build")
		set(_meson TRUE)
	endif()

	if(_cmake AND _meson)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: '${srcdir}' has both CMakeLists.txt and meson.build — use create_cmake_component or create_meson_component")
	endif()
	if(_cmake)
		set(${out_var} "cmake" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_detect_build_system")
		return()
	endif()
	if(_meson)
		set(${out_var} "meson" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_detect_build_system")
		return()
	endif()

	_bm_log_message(COMPONENT FATAL
		"buildmaster_component: unknown build system in '${srcdir}' (need CMakeLists.txt or meson.build)")
endfunction()

## @brief Split `KEY=value` (first `=`). Empty key is FATAL.
function(_bm_factory_split_pair item out_key out_val)
	if(NOT item MATCHES "^([^=]+)=(.*)$")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: option '${item}' is not KEY=value")
	endif()
	set(${out_key} "${CMAKE_MATCH_1}" PARENT_SCOPE)
	set(${out_val} "${CMAKE_MATCH_2}" PARENT_SCOPE)
endfunction()

## @brief Resolve INCLUDES= path against srcdir. Missing path is FATAL.
function(_bm_factory_resolve_include srcdir raw out_var)
	if("${raw}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: INCLUDES= is empty")
	endif()
	if(IS_ABSOLUTE "${raw}")
		set(_p "${raw}")
	else()
		set(_p "${srcdir}/${raw}")
	endif()
	get_filename_component(_p "${_p}" ABSOLUTE)
	if(NOT IS_DIRECTORY "${_p}")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: INCLUDES='${raw}' is not a directory (${_p})")
	endif()
	set(${out_var} "${_p}" PARENT_SCOPE)
endfunction()

## @brief Translate a neutral options list into backend configure args.
## @param[in]  sys     `cmake` or `meson`.
## @param[in]  srcdir  For resolving relative INCLUDES.
## @param[in]  raw     CMake list of KEY=value (CFLAGS, CXXFLAGS, CPPFLAGS,
##            LDFLAGS, INCLUDES, DEFINITIONS). Other keys FATAL.
## @param[out] out_var Backend list: CMake `-D…` or Meson `-D…`.
## @note Appends to the parent job flags. Never replaces CMAKE_* / meson
##       args the toolchain already set. Not ENV{CFLAGS}. Private to the
##       nested compile — not INTERFACE on the BM id.
function(_bm_factory_translate_options sys srcdir raw out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_factory_translate_options")
	set(_c "")
	set(_cxx "")
	set(_ld "")
	set(_inc "")
	set(_def "")

	foreach(_item IN LISTS raw)
		if("${_item}" STREQUAL "")
			continue()
		endif()
		_bm_factory_split_pair("${_item}" _k _v)
		string(TOUPPER "${_k}" _k)
		if(_k STREQUAL "CFLAGS")
			string(APPEND _c " ${_v}")
		elseif(_k STREQUAL "CXXFLAGS")
			string(APPEND _cxx " ${_v}")
		elseif(_k STREQUAL "CPPFLAGS")
			string(APPEND _c " ${_v}")
			string(APPEND _cxx " ${_v}")
		elseif(_k STREQUAL "LDFLAGS")
			string(APPEND _ld " ${_v}")
		elseif(_k STREQUAL "INCLUDES")
			_bm_factory_resolve_include("${srcdir}" "${_v}" _p)
			list(APPEND _inc "${_p}")
		elseif(_k STREQUAL "DEFINITIONS")
			if("${_v}" STREQUAL "")
				_bm_log_message(COMPONENT FATAL
					"buildmaster_component: DEFINITIONS= is empty")
			endif()
			list(APPEND _def "${_v}")
		else()
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component: unknown option '${_k}=' (allowed: CFLAGS CXXFLAGS CPPFLAGS LDFLAGS INCLUDES DEFINITIONS)")
		endif()
	endforeach()

	foreach(_p IN LISTS _inc)
		string(APPEND _c " -I${_p}")
		string(APPEND _cxx " -I${_p}")
	endforeach()
	foreach(_d IN LISTS _def)
		string(APPEND _c " -D${_d}")
		string(APPEND _cxx " -D${_d}")
	endforeach()

	string(STRIP "${_c}" _c)
	string(STRIP "${_cxx}" _cxx)
	string(STRIP "${_ld}" _ld)

	set(_out "")
	if(sys STREQUAL "cmake")
		set(_pc "$CACHE{CMAKE_C_FLAGS}")
		set(_pcxx "$CACHE{CMAKE_CXX_FLAGS}")
		set(_pe "$CACHE{CMAKE_EXE_LINKER_FLAGS}")
		set(_ps "$CACHE{CMAKE_SHARED_LINKER_FLAGS}")
		if(_pc STREQUAL "")
			set(_pc "${CMAKE_C_FLAGS}")
		endif()
		if(_pcxx STREQUAL "")
			set(_pcxx "${CMAKE_CXX_FLAGS}")
		endif()
		if(_pe STREQUAL "")
			set(_pe "${CMAKE_EXE_LINKER_FLAGS}")
		endif()
		if(_ps STREQUAL "")
			set(_ps "${CMAKE_SHARED_LINKER_FLAGS}")
		endif()
		if(NOT _c STREQUAL "")
			list(APPEND _out "-DCMAKE_C_FLAGS=${_pc} ${_c}")
		endif()
		if(NOT _cxx STREQUAL "")
			list(APPEND _out "-DCMAKE_CXX_FLAGS=${_pcxx} ${_cxx}")
		endif()
		if(NOT _ld STREQUAL "")
			list(APPEND _out
				"-DCMAKE_EXE_LINKER_FLAGS=${_pe} ${_ld}"
				"-DCMAKE_SHARED_LINKER_FLAGS=${_ps} ${_ld}")
		endif()
	else()
		if(NOT _c STREQUAL "")
			list(APPEND _out "-Dc_args=${_c}")
		endif()
		if(NOT _cxx STREQUAL "")
			list(APPEND _out "-Dcpp_args=${_cxx}")
		endif()
		if(NOT _ld STREQUAL "")
			list(APPEND _out "-Dc_link_args=${_ld}" "-Dcpp_link_args=${_ld}")
		endif()
	endif()

	set(${out_var} "${_out}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_translate_options")
endfunction()

## @brief Register a component; backend is inferred from `srcdir`.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory. Must contain exactly one of
##            `CMakeLists.txt` or `meson.build`.
## @param[in] … Same remaining arity as `create_cmake_component` /
##            `create_meson_component`:
##            2.1: `options mode produced [optstr]`
##            with path: `builddir options mode produced [optstr]`.
## @param[in] options CMake list of `KEY=value`. Allowed keys (all
##            private to the nested compile, never INTERFACE on `<id>`):
##            `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS` (append to the
##            parent job / toolchain; do not replace),
##            `INCLUDES` (directory; relative to `srcdir`),
##            `DEFINITIONS` (`FOO` or `FOO=1` → `-D`).
##            Any other key is FATAL. Not shell `ENV{CFLAGS}`. Not raw
##            CMake `-D` / Meson `-D`.
## @note Both marker files or neither: FATAL. Then use create_cmake_* or
##       create_meson_*.
## @note `mode` is still the caller’s (`static` / `shared` / `headers`).
## @note optstr (`LINK=`, `PC=`, `WHOLE`, …) is unchanged and last.
## @note INTERFACE `<id>` exists on return (delegates to create_*).
function(buildmaster_component _component _component_title _srcdir)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_component")

	if(ARGC LESS 6 OR ARGC GREATER 8)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: expected 6–8 arguments (same arity as create_cmake_component)")
	endif()
	if("${_srcdir}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component('${_component}'): empty source directory")
	endif()

	set(_builddir "")
	set(_options "")
	set(_library_mode "")
	set(_produced "")
	set(_options_string "")
	set(_legacy FALSE)

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

	_bm_detect_build_system("${_srcdir}" _sys)
	_bm_factory_translate_options("${_sys}" "${_srcdir}" "${_options}" _xopts)
	_bm_log_message(COMPONENT DEBUG
		"buildmaster_component('${_component}'): ${_sys}")

	if(_legacy)
		if(_sys STREQUAL "cmake")
			create_cmake_component(
				"${_component}" "${_component_title}" "${_srcdir}"
				"${_builddir}" "${_xopts}" "${_library_mode}"
				"${_produced}" "${_options_string}")
		else()
			create_meson_component(
				"${_component}" "${_component_title}" "${_srcdir}"
				"${_builddir}" "${_xopts}" "${_library_mode}"
				"${_produced}" "${_options_string}")
		endif()
	else()
		if(_sys STREQUAL "cmake")
			create_cmake_component(
				"${_component}" "${_component_title}" "${_srcdir}"
				"${_xopts}" "${_library_mode}"
				"${_produced}" "${_options_string}")
		else()
			create_meson_component(
				"${_component}" "${_component_title}" "${_srcdir}"
				"${_xopts}" "${_library_mode}"
				"${_produced}" "${_options_string}")
		endif()
	endif()

	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_component")
endfunction()
