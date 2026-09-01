# cmake -DOUTPUTS="path1;path2" -DBINDIR=... -DBUILDMASTER_SRCDIR=... -P
# normalize_install_executables.cmake
#
# Rename upstream variant binaries to the canonical produced paths.
# Does not read RENAME=; the oficio list decides whether this runs.
#
# Each OUTPUT is a file under BINDIR (or its own directory):
#   Unix    → <stem>
#   Windows → <stem>.exe  (never <stem>.exe.exe)
# Stem case is taken from the produced basename.

if(NOT DEFINED OUTPUTS OR OUTPUTS STREQUAL "")
	return()
endif()

if(NOT DEFINED BUILDMASTER_SRCDIR OR BUILDMASTER_SRCDIR STREQUAL "")
	message(FATAL_ERROR
		"normalize_install_executables: BUILDMASTER_SRCDIR is required")
endif()

include("${BUILDMASTER_SRCDIR}/log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${BUILDMASTER_SRCDIR}/component/rename/variants.cmake")

if(NOT DEFINED BINDIR)
	set(BINDIR "")
endif()

_bm_log_message(RENAME LOWLEVEL "Entering normalize_install_executables")
_bm_log_message(RENAME LOWLEVEL "OUTPUTS='${OUTPUTS}'")
_bm_log_message(RENAME LOWLEVEL "BINDIR='${BINDIR}'")

## @brief Split an executable filename into stem and suffix.
## @param[in]  _filename Basename or path.
## @param[out] _out_stem Parent-scope stem (no .exe).
## @param[out] _out_suffix Parent-scope `.exe` or empty.
## @note `.exe.exe` is treated as stem + `.exe` after collapsing.
function(_bm_component_rename_split_exec _filename _out_stem _out_suffix)
	get_filename_component(_bn "${_filename}" NAME)
	string(TOLOWER "${_bn}" _bn_l)
	if(_bn_l MATCHES "\\.exe$")
		string(LENGTH "${_bn}" _bnlen)
		math(EXPR _stemlen "${_bnlen} - 4")
		string(SUBSTRING "${_bn}" 0 ${_stemlen} _stem_part)
		set(${_out_stem} "${_stem_part}" PARENT_SCOPE)
		set(${_out_suffix} ".exe" PARENT_SCOPE)
	else()
		set(${_out_stem} "${_bn}" PARENT_SCOPE)
		set(${_out_suffix} "" PARENT_SCOPE)
	endif()
endfunction()

## @brief Glob variant names for one executable stem.
## @param[in]  stem     Canonical stem.
## @param[in]  suffix   `.exe` or empty.
## @param[out] out_list Parent-scope pattern list.
function(_bm_component_rename_exec_candidates stem suffix out_list)
	set(_names "")
	foreach(_v IN LISTS BUILDMASTER_RENAME_VARIANTS)
		list(APPEND _names "${stem}${_v}${suffix}")
	endforeach()
	list(APPEND _names "${stem}*${suffix}")
	set(${out_list} "${_names}" PARENT_SCOPE)
endfunction()

## @brief Find a non-canonical executable to rename onto `_out`.
## @param[in]  dir     Search directory.
## @param[in]  stem    Canonical stem.
## @param[in]  suffix  `.exe` or empty.
## @param[out] out_src Parent-scope source path, or empty.
function(_bm_component_rename_find_exec dir stem suffix out_src)
	_bm_log_message(RENAME LOWLEVEL
		"Entering _bm_component_rename_find_exec dir='${dir}' stem='${stem}' suffix='${suffix}'")
	set(_found "")
	_bm_component_rename_exec_candidates("${stem}" "${suffix}" _patterns)
	foreach(_pat IN LISTS _patterns)
		file(GLOB _hits "${dir}/${_pat}")
		foreach(_f IN LISTS _hits)
			if(IS_DIRECTORY "${_f}")
				continue()
			endif()
			get_filename_component(_bn "${_f}" NAME)
			string(TOLOWER "${_bn}" _bn_l)
			if(_bn_l MATCHES "\\.(pdb|dll|so|dylib|a|lib)$")
				continue()
			endif()
			get_filename_component(_want "${dir}/${stem}${suffix}" ABSOLUTE)
			get_filename_component(_have "${_f}" ABSOLUTE)
			if(_want STREQUAL _have)
				continue()
			endif()
			set(_found "${_f}")
			break()
		endforeach()
		if(NOT _found STREQUAL "")
			break()
		endif()
	endforeach()
	set(${out_src} "${_found}" PARENT_SCOPE)
	_bm_log_message(RENAME LOWLEVEL "Exiting _bm_component_rename_find_exec")
endfunction()

foreach(_out IN LISTS OUTPUTS)
	if(_out STREQUAL "")
		continue()
	endif()

	if(EXISTS "${_out}")
		_bm_log_message(RENAME INFO "rename exec: ${_out} already present (skip)")
		continue()
	endif()

	get_filename_component(_dir "${_out}" DIRECTORY)
	if(_dir STREQUAL "" AND NOT BINDIR STREQUAL "")
		set(_dir "${BINDIR}")
		set(_out "${BINDIR}/${_out}")
	endif()
	get_filename_component(_fn "${_out}" NAME)
	_bm_component_rename_split_exec("${_fn}" _stem _suffix)

	if(NOT IS_DIRECTORY "${_dir}")
		_bm_log_message(RENAME FATAL
			"rename exec: directory missing for '${_out}': ${_dir}")
	endif()

	_bm_component_rename_find_exec("${_dir}" "${_stem}" "${_suffix}" _src)
	if(_src STREQUAL "" AND NOT _suffix STREQUAL "")
		_bm_component_rename_find_exec("${_dir}" "${_stem}" "" _src)
	endif()
	if(_src STREQUAL "" AND _suffix STREQUAL "")
		_bm_component_rename_find_exec("${_dir}" "${_stem}" ".exe" _src)
	endif()
	if(_src STREQUAL "")
		_bm_log_message(RENAME FATAL
			"rename exec: no candidate for '${_out}' (stem='${_stem}') in ${_dir}")
	endif()

	file(RENAME "${_src}" "${_out}")
	_bm_log_message(RENAME INFO "rename exec: ${_src} → ${_out}")
endforeach()

_bm_log_message(RENAME LOWLEVEL "Exiting normalize_install_executables")
