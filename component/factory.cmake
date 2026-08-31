# =============================================================================
# component/factory.cmake — backend-agnostic public factory
# =============================================================================

## @brief Detect cmake / meson / none from files in `srcdir` and the mode.
## @param[in]  srcdir   Component source directory (already SOURCE=-resolved).
## @param[in]  mode     `static`, `shared`, or `headers`.
## @param[in]  backend  Override from `BACKEND=` (empty = detect).
## @param[out] out_var  Parent-scope `cmake`, `meson`, or `none`.
## @note Exactly one of `CMakeLists.txt` / `meson.build` → that backend.
##       Both markers → FATAL unless `backend` is a known name in
##       `BUILDMASTER_FACTORY_BACKENDS`. No recursion into subdirectories.
## @note `headers` + neither marker → `none`. `static` / `shared` +
##       neither marker → FATAL.
function(_bm_factory_detect srcdir mode backend out_var)
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
	string(TOLOWER "${backend}" _be)
	set(_cmake FALSE)
	set(_meson FALSE)
	if(EXISTS "${srcdir}/CMakeLists.txt")
		set(_cmake TRUE)
	endif()
	if(EXISTS "${srcdir}/meson.build")
		set(_meson TRUE)
	endif()

	if(NOT "${_be}" STREQUAL "")
		set(_known "${BUILDMASTER_FACTORY_BACKENDS}")
		if("${_known}" STREQUAL "")
			set(_known "cmake;meson")
		endif()
		set(_ok FALSE)
		foreach(_k IN LISTS _known)
			if(_be STREQUAL "${_k}")
				set(_ok TRUE)
				break()
			endif()
		endforeach()
		if(NOT _ok)
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component: BACKEND='${backend}' is not in BUILDMASTER_FACTORY_BACKENDS (${_known})")
		endif()
		set(${out_var} "${_be}" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_detect")
		return()
	endif()

	if(_cmake AND _meson)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: '${srcdir}' has both CMakeLists.txt and meson.build — set BACKEND=cmake or BACKEND=meson")
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
		"buildmaster_component: unknown build system in '${srcdir}' (need CMakeLists.txt or meson.build, or BACKEND=)")
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
## @param[in]  raw     CMake list of `KEY=value`, or a single string
##            that is one pair. Backend-agnostic: no `-D` required.
##            Idioms, rewritten for the backend:
##            `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS` (append to
##            the parent job / toolchain; do not replace),
##            `INCLUDES` (directory; relative to `srcdir`),
##            `DEFINITIONS` (`FOO` or `FOO=1` → compiler `-D`).
##            Every other pair is forwarded as `-DKEY=value` to the
##            nested CMake *or* Meson configure (Meson also uses `-D`,
##            not `-d`). A leading `-D` / `-d` / `/D` on the key is
##            stripped so `WITH_FOO=ON` and `-DWITH_FOO=ON` are the
##            same.
## @param[out] out_var Backend list of `-D…`. Empty if `sys` is `none`.
## @note Not `ENV{CFLAGS}`. Private to the nested configure / compile —
##       not INTERFACE on the BM id. `none` ignores the list.
function(_bm_factory_translate_options sys srcdir raw out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_factory_translate_options")
	set(_c "")
	set(_cxx "")
	set(_ld "")
	set(_inc "")
	set(_def "")
	set(_fwd "")

	if(sys STREQUAL "none")
		set(${out_var} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_translate_options")
		return()
	endif()

	foreach(_item IN LISTS raw)
		if("${_item}" STREQUAL "")
			continue()
		endif()
		_bm_factory_split_pair("${_item}" _k_raw _v)
		set(_k "${_k_raw}")
		if(_k MATCHES "^[/-][Dd](.+)$")
			set(_k "${CMAKE_MATCH_1}")
		endif()
		string(TOUPPER "${_k}" _k_up)
		if(_k_up STREQUAL "CFLAGS")
			string(APPEND _c " ${_v}")
		elseif(_k_up STREQUAL "CXXFLAGS")
			string(APPEND _cxx " ${_v}")
		elseif(_k_up STREQUAL "CPPFLAGS")
			string(APPEND _c " ${_v}")
			string(APPEND _cxx " ${_v}")
		elseif(_k_up STREQUAL "LDFLAGS")
			string(APPEND _ld " ${_v}")
		elseif(_k_up STREQUAL "INCLUDES")
			_bm_factory_resolve_include("${srcdir}" "${_v}" _p)
			list(APPEND _inc "${_p}")
		elseif(_k_up STREQUAL "DEFINITIONS")
			if("${_v}" STREQUAL "")
				_bm_log_message(COMPONENT FATAL
					"buildmaster_component: DEFINITIONS= is empty")
			endif()
			list(APPEND _def "${_v}")
		else()
			if("${_k}" STREQUAL "")
				_bm_log_message(COMPONENT FATAL
					"buildmaster_component: option key is empty in '${_item}'")
			endif()
			list(APPEND _fwd "-D${_k}=${_v}")
			_bm_log_message(COMPONENT DEBUG
				"option '${_k}=${_v}' forwarded to ${sys}")
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
	list(APPEND _out ${_fwd})

	set(${out_var} "${_out}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_factory_translate_options")
endfunction()

## @brief Register a component; backend is inferred from `srcdir` + mode.
## @param[in] _component Short component identifier.
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Source directory. `SOURCE=` (optstr) selects a child
##            of this path **before** detect. GIT ops stay on this
##            positional path (the git work tree), not on the SOURCE child.
##            For `static`/`shared`: exactly one of `CMakeLists.txt` or
##            `meson.build` unless `BACKEND=`.
##            For `headers`: those markers select cmake/meson; neither
##            marker selects `none`.
##            **By design ignored when `FILES` contains `SOURCE`:** the
##            unpacked tree is the only srcdir. A dummy or empty path is
##            accepted in that case (WARNING).
## @param[in] options CMake list of `KEY=value` (one string is a
##            one-element list). Human-readable, backend-agnostic.
## @param[in] mode `static`, `shared`, or `headers`.
## @param[in] produced Library specs (`<name>` or `<subdir>/<name>`). Empty
##            for headers.
## @param[in] optstr Optional trailing `KEY=value;…`. `SOURCE=` and
##            `BACKEND=` are read here, before detect. `ALIAS=` /
##            `ALIAS={…}` is applied after the INTERFACE stub
##            (`_bm_alias_apply`).
## @note No build-directory argument. BuildMaster assigns
##       `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` via `_bm_path_component_builddir`.
## @note Both marker files without `BACKEND=`: FATAL.
## @note INTERFACE `<id>` exists on return (or already existed).
## @note A second `buildmaster_component` with the same `_component` is a
##       no-op. Same process: STATUS
##       `Skipping configure of <title> — already registered as '<winner>' (<id>)`.
##       Other process that already wrote `${BUILDMASTER_LINKS_DIR}/<id>.cmake`:
##       that file is `include`d and STATUS
##       `Skipping configure of <title> — already built by '<winner>' (<id>)`.
##       Identity is the id, not srcdir. The first registration wins.
## @note `ALIAS=` empty / `ALIAS={}` is FATAL. Alias equal to `<id>` or a
##       TARGET that is not already an ALIAS of `<id>` is FATAL.
function(buildmaster_component _component _component_title _srcdir
		_options _library_mode _produced)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_component")

	if(ARGC LESS 6 OR ARGC GREATER 7)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_component: expected id title srcdir options mode produced [optstr]")
	endif()

	_bm_links_try_reuse("${_component}" "${_component_title}" _reuse)
	if(_reuse)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_component")
		return()
	endif()

	set(_options_string "")
	if(ARGC EQUAL 7)
		set(_options_string "${ARGV6}")
	endif()

	set(_opt_source "")
	set(_opt_backend "")
	if(NOT "${_options_string}" STREQUAL "")
		_bm_opt_split_pairs("${_options_string}" _pairs)
		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()
			_bm_opt_split_pair("${_pair}" _key _val _ok)
			if(NOT _ok)
				continue()
			endif()
			if(_key STREQUAL "SOURCE")
				if("${_val}" STREQUAL "")
					_bm_log_message(COMPONENT FATAL
						"buildmaster_component('${_component}'): SOURCE= requires a directory")
				endif()
				set(_opt_source "${_val}")
			elseif(_key STREQUAL "BACKEND")
				if("${_val}" STREQUAL "")
					_bm_log_message(COMPONENT FATAL
						"buildmaster_component('${_component}'): BACKEND= requires cmake or meson")
				endif()
				set(_opt_backend "${_val}")
			endif()
		endforeach()
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

	set(_src_pos "${_srcdir}")
	set(_src_build "${_srcdir}")

	if(_files_has_source)
		_bm_log_message(COMPONENT WARNING
			"buildmaster_component('${_component}'): srcdir ignored because FILES SOURCE supplies the tree")
		set(_sys "pending")
		set(_xopts "")
		if("${_src_pos}" STREQUAL "")
			set(_src_pos "${CMAKE_CURRENT_SOURCE_DIR}")
			set(_src_build "${_src_pos}")
		endif()
	else()
		if("${_src_pos}" STREQUAL "")
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component('${_component}'): empty source directory")
		endif()
		if(NOT "${_opt_source}" STREQUAL "")
			_bm_comp_git_worktree(_src_build "${_src_pos}" "${_opt_source}")
		endif()
		_bm_factory_detect("${_src_build}" "${_library_mode}" "${_opt_backend}" _sys)
		_bm_factory_translate_options("${_sys}" "${_src_build}" "${_options}" _xopts)
	endif()

	set_property(GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_GIT_WORKDIR "${_src_pos}")

	_bm_log_message(COMPONENT DEBUG
		"buildmaster_component('${_component}'): ${_sys}")

	if(_sys STREQUAL "none" OR _sys STREQUAL "pending")
		_bm_graph_create(
			"${_component}" "${_component_title}" "${_src_build}"
			"${_xopts}" "${_library_mode}"
			"${_sys}" "${_produced}" "${_options_string}")
	elseif(_sys STREQUAL "cmake")
		_bm_backend_cmake_create(
			"${_component}" "${_component_title}" "${_src_build}"
			"${_xopts}" "${_library_mode}"
			"${_produced}" "${_options_string}")
	else()
		_bm_backend_meson_create(
			"${_component}" "${_component_title}" "${_src_build}"
			"${_xopts}" "${_library_mode}"
			"${_produced}" "${_options_string}")
	endif()

	set_property(GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_component}_FACTORY_OPTIONS "${_options}")

	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_component")
endfunction()
