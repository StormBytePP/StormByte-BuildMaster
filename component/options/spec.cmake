# =============================================================================
# component/options/spec.cmake — produced spec + whole-archive items
# =============================================================================

## @brief Split a produced spec into CMake target, basename and subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>` (subdir may contain `/`).
## @param[out] out_target  Imported CMake target name (`/` replaced with `_`).
## @param[out] out_libname Basename without prefix/suffix.
## @param[out] out_subdir  Directory relative to the mode base dir, or empty.
## @note Empty spec or a trailing slash with no name is FATAL.
## @note Same splitter for libraries and executables. The base dir is
##       chosen by `_bm_opt_append_spec` (`LIBDIR` vs `BINDIR`).
function(_bm_opt_parse_spec spec out_target out_libname out_subdir)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_spec")
	if("${spec}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_opt_parse_spec: empty produced spec")
	endif()

	string(FIND "${spec}" "/" _slash)
	if(_slash EQUAL -1)
		set(_tgt "${spec}")
		set(_name "${spec}")
		set(_dir "")
	else()
		get_filename_component(_name "${spec}" NAME)
		get_filename_component(_dir "${spec}" DIRECTORY)
		string(REPLACE "/" "_" _tgt "${spec}")
	endif()

	if("${_name}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_opt_parse_spec: missing name in '${spec}'")
	endif()

	set(${out_target} "${_tgt}" PARENT_SCOPE)
	set(${out_libname} "${_name}" PARENT_SCOPE)
	set(${out_subdir} "${_dir}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_spec")
endfunction()

## @brief Resolve one produced spec into name + file path (+ MSVC DLL).
## @param[in]  library_mode `static`, `shared`, or `executable`.
## @param[in]  spec         Spec (`<name>` or `<subdir>/<name>`).
## @param[in]  base_libdir  Root: `BUILDMASTER_INSTALL_LIBDIR` (libraries),
##            `BUILDMASTER_INSTALL_BINDIR` (`executable`), or the component
##            BUILDDIR when NOINSTALL.
## @param[out] names_var    List variable receiving the imported target name.
## @param[out] files_var    List variable receiving the artifact path.
## @param[out] dlls_var     List variable receiving the MSVC DLL path (shared
##            only). Empty for `executable`.
## @note `executable`: `${base}/${subdir}/${name}${CMAKE_EXECUTABLE_SUFFIX}`
##       (`.exe` on Windows, empty on Unix). Never `lib<name>.a`.
## @note Produced basenames keep the case of `spec`.
## @note This is a macro so the caller's list variables are appended in place.
macro(_bm_opt_append_spec library_mode spec base_libdir
									names_var files_var dlls_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_append_spec")
	_bm_opt_parse_spec("${spec}" _bm_as_tgt _bm_as_name _bm_as_subdir)
	list(APPEND ${names_var} "${_bm_as_tgt}")
	if("${library_mode}" STREQUAL "executable")
		set(_bm_as_dir "${base_libdir}")
		if(NOT "${_bm_as_subdir}" STREQUAL "")
			set(_bm_as_dir "${_bm_as_dir}/${_bm_as_subdir}")
		endif()
		list(APPEND ${files_var}
			"${_bm_as_dir}/${_bm_as_name}${CMAKE_EXECUTABLE_SUFFIX}")
	elseif("${library_mode}" STREQUAL "static")
		_bm_lib_import_static_hint(_bm_as_path "${_bm_as_name}"
			"${base_libdir}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
	else()
		_bm_lib_import_hint(_bm_as_path "${_bm_as_name}"
			"${base_libdir}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
		if(MSVC)
			if("${base_libdir}" STREQUAL "${BUILDMASTER_INSTALL_LIBDIR}")
				set(_bm_as_dll_dir "${BUILDMASTER_INSTALL_BINDIR}")
			else()
				set(_bm_as_dll_dir "${base_libdir}")
			endif()
			if(NOT "${_bm_as_subdir}" STREQUAL "")
				set(_bm_as_dll_dir "${_bm_as_dll_dir}/${_bm_as_subdir}")
			endif()
			list(APPEND ${dlls_var}
				"${_bm_as_dll_dir}/${_bm_as_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		endif()
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_append_spec")
endmacro()

## @brief Register the ELF WHOLE group feature (CMake 3.24+).
## @note CMake classifies `-Wl,--whole-archive` as a *flag* and `*.a` as a
##       *library*. `target_link_libraries(t INTERFACE -Wl,--whole-archive
##       libavutil.a … -Wl,--no-whole-archive)` therefore emits:
##
##         libavutil.a libavcodec.a …  -Wl,--whole-archive -Wl,--no-whole-archive
##
##       i.e. an empty wrap. `LINK_GROUP:BM_WHOLE` is one token and keeps
##       every produced archive between the two flags:
##
##         -Wl,--whole-archive libavutil.a libavcodec.a … -Wl,--no-whole-archive
## @brief Register the ELF WHOLE *group* feature (CMake 3.24+).
## @note This is LINK_GROUP, not LINK_LIBRARY. CMake looks up
##       CMAKE_<LANG>_LINK_GROUP_USING_<FEATURE>_SUPPORTED when a target
##       of that language consumes `$<LINK_GROUP:FEATURE,…>`. Without the
##       CXX/C entries, add_library() of a C++ DSO fails with:
##       Feature 'BM_WHOLE' … is not supported for the 'CXX' link language.
## @note Two-element form = prefix + suffix around every member:
##
##         -Wl,--whole-archive  <all produced .a>  -Wl,--no-whole-archive
function(_bm_opt_whole_enable_group)
	if(MSVC OR APPLE)
		return()
	endif()
	set(_prefix "LINKER:--whole-archive")
	set(_suffix "LINKER:--no-whole-archive")
	foreach(_var
			CMAKE_LINK_GROUP_USING_BM_WHOLE
			CMAKE_C_LINK_GROUP_USING_BM_WHOLE
			CMAKE_CXX_LINK_GROUP_USING_BM_WHOLE)
		set(${_var} "${_prefix}" "${_suffix}" CACHE INTERNAL
			"BuildMaster ELF WHOLE group")
	endforeach()
	foreach(_var
			CMAKE_LINK_GROUP_USING_BM_WHOLE_SUPPORTED
			CMAKE_C_LINK_GROUP_USING_BM_WHOLE_SUPPORTED
			CMAKE_CXX_LINK_GROUP_USING_BM_WHOLE_SUPPORTED)
		set(${_var} TRUE CACHE INTERNAL
			"BuildMaster ELF WHOLE group")
	endforeach()
endfunction()

## @brief Build whole-archive linker items for a list of static archive paths.
## @param[out] _out_var Name of the parent-scope variable to receive the item list.
## @param[in]  ARGN     Absolute (or install-relative) static archive paths.
## @note One closed region per component on ELF (`--whole-archive` … `--no-whole-archive`);
##       per-archive `-Wl,-force_load,` on Apple; `-WHOLEARCHIVE:` on MSVC.
##       MSVC uses the `-WHOLEARCHIVE:` spelling so Ninja does not treat a leading
##       `/WHOLEARCHIVE:` token as a filesystem path.
## @note ELF uses `$<LINK_GROUP:BM_WHOLE,…>` (not raw `-Wl` + paths). That
##       group is a single genex, survives `configure_file(@ONLY)`, and is
##       not split into flags-vs-libs by CMake.
function(_bm_opt_whole_items _out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_whole_items")
	set(_paths ${ARGN})
	set(_items "")
	if(NOT _paths)
		set(${_out_var} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_whole_items")
		return()
	endif()
	if(MSVC)
		foreach(_p IN LISTS _paths)
			list(APPEND _items "-WHOLEARCHIVE:${_p}")
		endforeach()
	elseif(APPLE)
		foreach(_p IN LISTS _paths)
			list(APPEND _items "-Wl,-force_load,${_p}")
		endforeach()
	else()
		_bm_opt_whole_enable_group()
		list(JOIN _paths "," _csv)
		set(_items "$<LINK_GROUP:BM_WHOLE,${_csv}>")
	endif()
	set(${_out_var} "${_items}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_whole_items")
endfunction()
