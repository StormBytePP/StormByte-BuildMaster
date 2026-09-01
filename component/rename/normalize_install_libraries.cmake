# cmake -DOUTPUTS="path1;path2" -DBINDIR=... -DBUILDMASTER_SRCDIR=... -P
# normalize_install_libraries.cmake
# Rename upstream variant archives to the canonical produced paths.
# Does not read RENAME=; the oficio list decides whether this runs.
#
# Each OUTPUT is renamed in its own directory:
#   static / Unix shared  → LIBDIR only
#   MSVC shared           → LIBDIR (.lib) and BINDIR (.dll) as two OUTPUTS
# Stem case is taken from the produced basename (StormByte.dll → StormByte).
#
# Static archives: if the canonical suffix is .lib and only a .a exists
# (or the reverse), accept that file as the source. Meson on Windows often
# installs libfoo.a while the IMPORTED contract is foo.lib.

if(NOT DEFINED OUTPUTS OR OUTPUTS STREQUAL "")
	return()
endif()

if(NOT DEFINED BUILDMASTER_SRCDIR OR BUILDMASTER_SRCDIR STREQUAL "")
	message(FATAL_ERROR "normalize_install_libraries: BUILDMASTER_SRCDIR is required")
endif()

include("${BUILDMASTER_SRCDIR}/log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

include("${BUILDMASTER_SRCDIR}/component/rename/variants.cmake")

if(NOT DEFINED BINDIR)
	set(BINDIR "")
endif()

_bm_log_message(RENAME LOWLEVEL "Entering normalize_install_libraries")
_bm_log_message(RENAME LOWLEVEL "OUTPUTS='${OUTPUTS}'")
_bm_log_message(RENAME LOWLEVEL "BINDIR='${BINDIR}'")
_bm_log_message(RENAME LOWLEVEL "VARIANTS='${BUILDMASTER_RENAME_VARIANTS}'")

# ---- helpers ----

## @brief Split an archive / import / shared filename into stem and suffix.
## @param[in]  _filename Basename or path.
## @param[out] _out_stem Parent-scope stem (no lib prefix).
## @param[out] _out_suffix Parent-scope suffix (`.a` / `.lib` / `.so` / …).
function(_bm_component_rename_split_name _filename _out_stem _out_suffix)
	get_filename_component(_bn "${_filename}" NAME)
	string(TOLOWER "${_bn}" _bn_l)

	if(_bn_l MATCHES "\\.dll$")
		set(_suf ".dll")
	elseif(_bn_l MATCHES "\\.dylib$")
		set(_suf ".dylib")
	elseif(_bn_l MATCHES "\\.so(\\..*)?$")
		set(_suf ".so")
	elseif(_bn_l MATCHES "\\.lib$")
		set(_suf ".lib")
	elseif(_bn_l MATCHES "\\.a$")
		set(_suf ".a")
	else()
		set(${_out_stem} "" PARENT_SCOPE)
		set(${_out_suffix} "" PARENT_SCOPE)
		return()
	endif()

	string(LENGTH "${_bn}" _bnlen)
	if(_bn_l MATCHES "\\.so\\..+$")
		string(TOLOWER "${_bn}" _tmp)
		string(FIND "${_tmp}" ".so" _so_pos)
		string(SUBSTRING "${_bn}" 0 ${_so_pos} _stem_part)
	else()
		string(LENGTH "${_suf}" _suflen)
		math(EXPR _stemlen "${_bnlen} - ${_suflen}")
		string(SUBSTRING "${_bn}" 0 ${_stemlen} _stem_part)
	endif()

	if(_stem_part MATCHES "^[Ll][Ii][Bb](.+)$")
		set(_stem_part "${CMAKE_MATCH_1}")
	endif()

	set(${_out_stem} "${_stem_part}" PARENT_SCOPE)
	set(${_out_suffix} "${_suf}" PARENT_SCOPE)
endfunction()

## @brief Build glob patterns for variant filenames of one stem + suffix.
## @param[in]  stem     Canonical stem.
## @param[in]  suffix   Archive / shared suffix.
## @param[out] out_list Parent-scope pattern list.
function(_bm_component_rename_candidate_names stem suffix out_list)
	set(_names "")
	foreach(_v IN LISTS BUILDMASTER_RENAME_VARIANTS)
		list(APPEND _names "${stem}${_v}${suffix}")
		list(APPEND _names "lib${stem}${_v}${suffix}")
	endforeach()
	list(APPEND _names "${stem}*${suffix}")
	list(APPEND _names "lib${stem}*${suffix}")
	set(${out_list} "${_names}" PARENT_SCOPE)
endfunction()

## @brief Locate a non-canonical source file to rename onto a produced path.
## @param[in]  dir     Search directory.
## @param[in]  stem    Canonical stem.
## @param[in]  suffix  Expected suffix.
## @param[out] out_src Parent-scope source path, or empty.
## @param[out] out_variant_token Parent-scope variant token after the stem.
function(_bm_component_rename_find_source dir stem suffix out_src out_variant_token)
	_bm_log_message(RENAME LOWLEVEL
		"Entering _bm_component_rename_find_source dir='${dir}' stem='${stem}' suffix='${suffix}'")

	set(_found "")
	set(_token "")
	_bm_component_rename_candidate_names("${stem}" "${suffix}" _patterns)
	_bm_log_message(RENAME LOWLEVEL "candidate patterns='${_patterns}'")

	foreach(_pat IN LISTS _patterns)
		file(GLOB _hits "${dir}/${_pat}")
		_bm_log_message(RENAME LOWLEVEL "glob '${dir}/${_pat}' hits='${_hits}'")
		foreach(_f IN LISTS _hits)
			if(IS_DIRECTORY "${_f}")
				_bm_log_message(RENAME LOWLEVEL "skip directory '${_f}'")
				continue()
			endif()
			get_filename_component(_bn "${_f}" NAME)
			string(TOLOWER "${_bn}" _bn_l)
			if(_bn_l MATCHES "\\.pdb$")
				_bm_log_message(RENAME LOWLEVEL "skip pdb '${_f}'")
				continue()
			endif()
			_bm_component_rename_split_name("${_bn}" _hs _hx)
			if(_hs STREQUAL "${stem}" AND _bn MATCHES "${stem}${suffix}$")
				get_filename_component(_want "${dir}/${stem}${suffix}" ABSOLUTE)
				get_filename_component(_have "${_f}" ABSOLUTE)
				if(_want STREQUAL _have)
					_bm_log_message(RENAME LOWLEVEL
						"skip exact canonical '${_f}'")
					continue()
				endif()
			endif()
			set(_found "${_f}")
			string(REGEX REPLACE "\\${suffix}$" "" _tok "${_bn}")
			if(_tok MATCHES "^[Ll][Ii][Bb](.+)$")
				set(_tok "${CMAKE_MATCH_1}")
			endif()
			string(LENGTH "${stem}" _slen)
			string(SUBSTRING "${_tok}" 0 ${_slen} _pref)
			if(_pref STREQUAL "${stem}")
				string(SUBSTRING "${_tok}" ${_slen} -1 _token)
			else()
				set(_token "")
			endif()
			_bm_log_message(RENAME DEBUG
				"find_source: picked '${_found}' token='${_token}' for stem='${stem}' suffix='${suffix}'")
			break()
		endforeach()
		if(NOT _found STREQUAL "")
			break()
		endif()
	endforeach()

	if(_found STREQUAL "")
		_bm_log_message(RENAME DEBUG
			"find_source: no hit in '${dir}' for stem='${stem}' suffix='${suffix}'")
	endif()

	set(${out_src} "${_found}" PARENT_SCOPE)
	set(${out_variant_token} "${_token}" PARENT_SCOPE)
	_bm_log_message(RENAME LOWLEVEL "Exiting _bm_component_rename_find_source")
endfunction()

## @brief Alternate static-archive suffixes for a missing canonical file.
## @param[in]  suffix   Canonical suffix.
## @param[out] out_list Parent-scope alternate suffix list.
function(_bm_component_rename_archive_alt_suffixes suffix out_list)
	set(_alts "")
	if(suffix STREQUAL ".lib")
		list(APPEND _alts ".a")
	elseif(suffix STREQUAL ".a")
		list(APPEND _alts ".lib")
	endif()
	set(${out_list} "${_alts}" PARENT_SCOPE)
endfunction()

# ---- main ----

foreach(_out IN LISTS OUTPUTS)
	if(_out STREQUAL "")
		continue()
	endif()

	_bm_log_message(RENAME DEBUG "consider '${_out}'")

	if(EXISTS "${_out}")
		_bm_log_message(RENAME INFO "rename: ${_out} already present (skip)")
		continue()
	endif()

	get_filename_component(_dir "${_out}" DIRECTORY)
	get_filename_component(_fn "${_out}" NAME)
	_bm_component_rename_split_name("${_fn}" _stem _suffix)
	if(_stem STREQUAL "" OR _suffix STREQUAL "")
		_bm_log_message(RENAME FATAL "rename: cannot parse stem/suffix from '${_fn}'")
	endif()

	_bm_log_message(RENAME DEBUG
		"missing '${_out}' → search dir='${_dir}' stem='${_stem}' suffix='${_suffix}'")

	if(NOT IS_DIRECTORY "${_dir}")
		_bm_log_message(RENAME FATAL "rename: directory missing for '${_out}': ${_dir}")
	endif()

	_bm_component_rename_find_source("${_dir}" "${_stem}" "${_suffix}" _src _vtok)
	if(_src STREQUAL "")
		_bm_component_rename_archive_alt_suffixes("${_suffix}" _alt_sufs)
		_bm_log_message(RENAME DEBUG
			"no candidate with suffix='${_suffix}', trying alts='${_alt_sufs}'")
		foreach(_alt IN LISTS _alt_sufs)
			_bm_component_rename_find_source("${_dir}" "${_stem}" "${_alt}" _src _vtok)
			if(NOT _src STREQUAL "")
				_bm_log_message(RENAME INFO
					"rename: using alternate suffix '${_alt}' for '${_fn}'")
				break()
			endif()
		endforeach()
	endif()
	if(_src STREQUAL "")
		_bm_log_message(RENAME FATAL
			"rename: no candidate for '${_out}' (stem='${_stem}' suffix='${_suffix}') in ${_dir}")
	endif()

	file(RENAME "${_src}" "${_out}")
	_bm_log_message(RENAME INFO "rename: ${_src} → ${_out}")

	if(_suffix STREQUAL ".lib" AND NOT BINDIR STREQUAL "")
		set(_dll_dst "${BINDIR}/${_stem}.dll")
		if(NOT EXISTS "${_dll_dst}")
			_bm_log_message(RENAME DEBUG
				"pair dll: missing '${_dll_dst}' token='${_vtok}'")
			set(_dll_src "")
			if(NOT _vtok STREQUAL "")
				if(EXISTS "${BINDIR}/${_stem}${_vtok}.dll")
					set(_dll_src "${BINDIR}/${_stem}${_vtok}.dll")
				elseif(EXISTS "${_dir}/${_stem}${_vtok}.dll")
					set(_dll_src "${_dir}/${_stem}${_vtok}.dll")
				endif()
			endif()
			if(_dll_src STREQUAL "")
				_bm_component_rename_find_source("${BINDIR}" "${_stem}" ".dll" _dll_src _dll_tok)
				if(_dll_src STREQUAL "" AND IS_DIRECTORY "${_dir}")
					_bm_component_rename_find_source("${_dir}" "${_stem}" ".dll" _dll_src _dll_tok)
				endif()
			endif()
			if(NOT _dll_src STREQUAL "" AND NOT EXISTS "${_dll_dst}")
				file(RENAME "${_dll_src}" "${_dll_dst}")
				_bm_log_message(RENAME INFO "rename: ${_dll_src} → ${_dll_dst}")
			else()
				_bm_log_message(RENAME DEBUG
					"pair dll: no source for '${_dll_dst}'")
			endif()
		endif()
	endif()
endforeach()

_bm_log_message(RENAME LOWLEVEL "Exiting normalize_install_libraries")
