# =============================================================================
# component/options/spec.cmake — library spec + whole-archive items
# =============================================================================

## @brief Split a library spec into CMake target, library basename and libdir subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>` (subdir may contain `/`).
## @param[out] out_target  Imported CMake target name (`/` replaced with `_`).
## @param[out] out_libname Library basename without prefix/suffix.
## @param[out] out_subdir  Directory relative to the library base dir, or empty.
## @note Empty spec or a trailing slash with no name is FATAL.
function(_bm_opt_parse_spec spec out_target out_libname out_subdir)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_parse_spec")
	if("${spec}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_opt_parse_spec: empty library spec")
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
			"_bm_opt_parse_spec: missing library name in '${spec}'")
	endif()

	set(${out_target} "${_tgt}" PARENT_SCOPE)
	set(${out_libname} "${_name}" PARENT_SCOPE)
	set(${out_subdir} "${_dir}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_parse_spec")
endfunction()

## @brief Resolve one library spec into IMPORTED name + file path (+ MSVC DLL).
## @param[in]  library_mode `static` or `shared`.
## @param[in]  spec         Library spec (`<name>` or `<subdir>/<name>`).
## @param[in]  base_libdir  Root for archives / import libs
##            (`BUILDMASTER_INSTALL_LIBDIR`, or the component BUILDDIR when
##            BUILDONLY).
## @param[out] names_var    List variable receiving the imported target name.
## @param[out] files_var    List variable receiving the archive/import path
##            under `base_libdir` (GNUInstallDirs ARCHIVE → LIBDIR).
## @param[out] dlls_var     List variable receiving the MSVC DLL path (shared
##            only). On an install prefix that is RUNTIME → BINDIR; BUILDONLY
##            keeps the DLL next to the other artifacts in BUILDDIR.
## @note Produced basenames keep the case of `spec` (`StormByte`, not
##       `stormbyte`).
## @note BUILDONLY must pass the component's own BUILDDIR — never the parent
##       install prefix or another component's build tree.
##       This is a macro so the caller's list variables are appended in place.
macro(_bm_opt_append_spec library_mode spec base_libdir
									names_var files_var dlls_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_opt_append_spec")
	_bm_opt_parse_spec("${spec}" _bm_as_tgt _bm_as_name _bm_as_subdir)
	list(APPEND ${names_var} "${_bm_as_tgt}")
	if("${library_mode}" STREQUAL "static")
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

## @brief Build whole-archive linker items for a list of static archive paths.
## @param[out] _out_var Name of the parent-scope variable to receive the item list.
## @param[in]  ARGN     Absolute (or install-relative) static archive paths.
## @note One closed region per component on ELF (`--whole-archive` … `--no-whole-archive`);
##       per-archive `-Wl,-force_load,` on Apple; `-WHOLEARCHIVE:` on MSVC.
##       MSVC uses the `-WHOLEARCHIVE:` spelling so Ninja does not treat a leading
##       `/WHOLEARCHIVE:` token as a filesystem path.
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
		list(APPEND _items "-Wl,--whole-archive")
		foreach(_p IN LISTS _paths)
			list(APPEND _items "${_p}")
		endforeach()
		list(APPEND _items "-Wl,--no-whole-archive")
	endif()
	set(${_out_var} "${_items}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_opt_whole_items")
endfunction()
