# =============================================================================
# component/factory.cmake — backend-agnostic public factory
# =============================================================================

## @brief Detect cmake / meson / none from files in `srcdir` and the mode.
## @param[in]  srcdir  Component source directory.
## @param[in]  mode    `static`, `shared`, or `headers`.
## @param[out] out_var Parent-scope `cmake`, `meson`, or `none`.
## @note Exactly one of `CMakeLists.txt` / `meson.build` → that backend.
##       Both markers → FATAL. No recursion into subdirectories.
## @note `headers` + neither marker → `none` (private tree, no nested
##       generate). `static` / `shared` + neither marker → FATAL.
function(_bm_factory_detect srcdir mode out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_factory_detect")
	if("${srcdir}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_factory_detect: empty source directory")
	endif()
	if(NOT IS_DIRECTORY "${srcdir}")
		_bm_log_message(COMPONENT FATAL
			"_bm_factory_detect: '${srcdir}' is not a directory")
	endif()

	string(TOLOWER "${mode}" _mode)
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
			"buildmaster_component: '${srcdir}' has both CMakeLists.txt and meson.build — use _bm_backend_cmake_create or _bm_backend_meson_create")
	endif()
	if(_cmake)
		set(${out_var} "cmake" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_detect")
		return()
	endif()
	if(_meson)
		set(${out_var} "meson" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_detect")
		return()
	endif()

	if(_mode STREQUAL "headers")
		set(${out_var} "none" PARENT_SCOPE)
		_bm_log_message(COMPONENT DEBUG
			"_bm_factory_detect: headers without backend → none")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_detect")
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
## @param[in]  sys     `cmake`, `meson`, or `none`.
## @param[in]  srcdir  For resolving relative INCLUDES.
## @param[in]  raw     CMake list of KEY=value (CFLAGS, CXXFLAGS, CPPFLAGS,
##            LDFLAGS, INCLUDES, DEFINITIONS). Other keys FATAL.
## @param[out] out_var Backend list: CMake `-D…` or Meson `-D…`. Empty if
##            `sys` is `none` (no nested configure).
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

	if(sys STREQUAL "none")
		set(${out_var} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_translate_options")
		return()
	endif()

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
		_bm_path_compile_include(_tok "${_p}")
		string(APPEND _c " ${_tok}")
		string(APPEND _cxx " ${_tok}")
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

## @brief Register a component; backend is inferred from `srcdir` + mode.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory. For `static`/`shared`: exactly one
##            of `CMakeLists.txt` or `meson.build`. For `headers`: those
##            markers select cmake/meson; neither marker selects `none`
##            (private include tree, no nested generate).
##            **By design ignored when `FILES` contains `SOURCE`:** the
##            unpacked tree is the only srcdir. A dummy or empty path is
##            accepted in that case (WARNING).
## @param[in] options CMake list of `KEY=value`. Allowed keys (all
##            private to the nested compile, never INTERFACE on `<id>`):
##            `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS` (append to the
##            parent job / toolchain; do not replace),
##            `INCLUDES` (directory; relative to `srcdir`),
##            `DEFINITIONS` (`FOO` or `FOO=1` → `-D`).
##            Any other key is FATAL. Not shell `ENV{CFLAGS}`. Not raw
##            CMake `-D` / Meson `-D`. Ignored when the backend is `none`.
## @param[in] mode `static`, `shared`, or `headers`.
## @param[in] produced Library specs (`<name>` or `<subdir>/<name>`). Empty
##            for headers.
## @param[in] optstr Optional trailing `KEY=value;…` (`LINK=`, `PC=`,
##            `WHOLE`, `GIT={…}`, `FILES={…}`, …). GIT / FILES run from
##            materialize after the INTERFACE exists.
## @note Invoked only from the public macro `buildmaster_component`.
##       Not a project API.
## @note No build-directory argument. BuildMaster assigns
##       `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` via `_bm_path_component_builddir`.
## @note Both marker files: FATAL.
## @note INTERFACE `<id>` exists on return.
function(_bm_component_impl _component _component_title _srcdir
		_options _library_mode _produced)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_component_impl")

	if(ARGC LESS 6 OR ARGC GREATER 7)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: expected id title srcdir options mode produced [optstr]")
	endif()

	set(_options_string "")
	if(ARGC EQUAL 7)
		set(_options_string "${ARGV6}")
	endif()

	_bm_opt_parse_files(
		"${_options_string}" _files_present
		_files_urls _files_names _files_hashes _files_algos
		_files_unpacks _files_forces _files_sources _files_titles)
	set(_files_has_source FALSE)
	foreach(_so IN LISTS _files_sources)
		if(NOT "${_so}" STREQUAL "")
			set(_files_has_source TRUE)
			break()
		endif()
	endforeach()

	if(_files_has_source)
		_bm_log_message(COMPONENT WARNING
			"buildmaster_component('${_component}'): srcdir ignored because FILES SOURCE supplies the tree")
		set(_sys "pending")
		set(_xopts "")
		if("${_srcdir}" STREQUAL "")
			set(_srcdir "${CMAKE_CURRENT_SOURCE_DIR}")
		endif()
	else()
		if("${_srcdir}" STREQUAL "")
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component('${_component}'): empty source directory")
		endif()
		_bm_factory_detect("${_srcdir}" "${_library_mode}" _sys)
		_bm_factory_translate_options("${_sys}" "${_srcdir}" "${_options}" _xopts)
	endif()

	_bm_log_message(COMPONENT DEBUG
		"buildmaster_component('${_component}'): ${_sys}")

	if(_sys STREQUAL "none" OR _sys STREQUAL "pending")
		_bm_graph_create(
			"${_component}" "${_component_title}" "${_srcdir}"
			"${_xopts}" "${_library_mode}"
			"${_sys}" "${_produced}" "${_options_string}")
	elseif(_sys STREQUAL "cmake")
		_bm_backend_cmake_create(
			"${_component}" "${_component_title}" "${_srcdir}"
			"${_xopts}" "${_library_mode}"
			"${_produced}" "${_options_string}")
	else()
		_bm_backend_meson_create(
			"${_component}" "${_component_title}" "${_srcdir}"
			"${_xopts}" "${_library_mode}"
			"${_produced}" "${_options_string}")
	endif()

	set_property(GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_FACTORY_OPTIONS "${_options}")

	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_component_impl")
endfunction()

## @brief Public factory (macro so id origin is the caller's CMakeLists).
## @see _bm_component_impl
macro(buildmaster_component)
	if(${ARGC} LESS 1)
		_bm_log_message(COMPONENT FATAL "buildmaster_component: missing id")
	endif()
	_bm_id_stamp("${ARGV0}" component
		"${CMAKE_CURRENT_LIST_FILE}" "${CMAKE_CURRENT_LIST_LINE}")
	if(${ARGC} EQUAL 6)
		_bm_component_impl("${ARGV0}" "${ARGV1}" "${ARGV2}"
			"${ARGV3}" "${ARGV4}" "${ARGV5}")
	elseif(${ARGC} EQUAL 7)
		_bm_component_impl("${ARGV0}" "${ARGV1}" "${ARGV2}"
			"${ARGV3}" "${ARGV4}" "${ARGV5}" "${ARGV6}")
	else()
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: expected id title srcdir options mode produced [optstr]")
	endif()
endmacro()
