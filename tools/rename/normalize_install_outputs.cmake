# cmake -DOUTPUTS="path1;path2" -DBINDIR=... -DBUILDMASTER_SRCDIR=... -P normalize_install_outputs.cmake
# Rename upstream variant archives to the canonical produced paths.
# Does not read RENAME=; the caller (install_exec) decides whether to run this.

if(NOT DEFINED OUTPUTS OR OUTPUTS STREQUAL "")
	return()
endif()

if(NOT DEFINED BUILDMASTER_SRCDIR OR BUILDMASTER_SRCDIR STREQUAL "")
	# log.cmake is not reachable without SRCDIR — this is the only raw message()
	# allowed in this file.
	message(FATAL_ERROR "normalize_install_outputs: BUILDMASTER_SRCDIR is required")
endif()

include("${BUILDMASTER_SRCDIR}/log.cmake")
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
endif()

include("${BUILDMASTER_SRCDIR}/tools/rename/variants.cmake")

if(NOT DEFINED BINDIR)
	set(BINDIR "")
endif()

# ---- helpers ----

## @brief Split an archive / import / shared filename into stem and suffix.
## @param[in]  _filename   Basename or path (only the filename is used).
## @param[out] _out_stem   Parent-scope stem without a leading `lib` prefix
##                         (e.g. `z` from `libz.a` or `z.lib`). Empty if the
##                         name is not a recognised library filename.
## @param[out] _out_suffix Parent-scope suffix including the dot: `.a`,
##                         `.lib`, `.dll`, `.so`, or `.dylib`. Empty when
##                         the stem is empty.
## @note Matching is case-insensitive. A trailing SONAME suffix after `.so`
##       (e.g. `.so.1.2`) is treated as `.so`. PDB files are not parsed here.
function(_bm_rename_split_name _filename _out_stem _out_suffix)
	get_filename_component(_bn "${_filename}" NAME)
	string(TOLOWER "${_bn}" _bn_l)

	# dll / so / dylib / a / lib
	if(_bn_l MATCHES "^(.*)\\.(dll)$")
		set(_stem_part "${CMAKE_MATCH_1}")
		set(_suf ".dll")
	elseif(_bn_l MATCHES "^(.*)\\.(dylib)$")
		set(_stem_part "${CMAKE_MATCH_1}")
		set(_suf ".dylib")
	elseif(_bn_l MATCHES "^(.*)\\.(so)(\\..*)?$")
		set(_stem_part "${CMAKE_MATCH_1}")
		set(_suf ".so")
	elseif(_bn_l MATCHES "^(.*)\\.(lib)$")
		set(_stem_part "${CMAKE_MATCH_1}")
		set(_suf ".lib")
	elseif(_bn_l MATCHES "^(.*)\\.(a)$")
		set(_stem_part "${CMAKE_MATCH_1}")
		set(_suf ".a")
	else()
		set(${_out_stem} "" PARENT_SCOPE)
		set(${_out_suffix} "" PARENT_SCOPE)
		return()
	endif()

	# Drop optional lib prefix for matching (libz.a / z.lib → stem z)
	if(_stem_part MATCHES "^[Ll][Ii][Bb](.+)$")
		set(_stem_part "${CMAKE_MATCH_1}")
	endif()

	set(${_out_stem} "${_stem_part}" PARENT_SCOPE)
	set(${_out_suffix} "${_suf}" PARENT_SCOPE)
endfunction()

## @brief Build glob patterns for variant filenames of one stem + suffix.
## @param[in]  stem     Canonical stem without `lib` prefix (e.g. `z`).
## @param[in]  suffix   File suffix including the dot (e.g. `.a`, `.lib`).
## @param[out] out_list Parent-scope CMake list of filename patterns.
## @note For each token in `BUILDMASTER_RENAME_VARIANTS` two names are
##       appended: `${stem}${variant}${suffix}` and
##       `lib${stem}${variant}${suffix}`. A broad fallback
##       `${stem}*${suffix}` / `lib${stem}*${suffix}` is appended last.
##       The caller still filters PDB files and exact canonical hits.
function(_bm_rename_candidate_names stem suffix out_list)
	set(_names "")
	foreach(_v IN LISTS BUILDMASTER_RENAME_VARIANTS)
		list(APPEND _names "${stem}${_v}${suffix}")
		list(APPEND _names "lib${stem}${_v}${suffix}")
	endforeach()
	# Broad fallback (still filtered to same suffix / non-pdb)
	list(APPEND _names "${stem}*${suffix}")
	list(APPEND _names "lib${stem}*${suffix}")
	set(${out_list} "${_names}" PARENT_SCOPE)
endfunction()

## @brief Locate a non-canonical source file to rename onto a produced path.
## @param[in]  dir               Directory to search (`file(GLOB)`).
## @param[in]  stem              Canonical stem (no `lib` prefix).
## @param[in]  suffix            Canonical suffix including the dot.
## @param[out] out_src           Parent-scope absolute-or-glob path of the
##                               first acceptable candidate, or empty.
## @param[out] out_variant_token Parent-scope variant piece left after
##                               stripping `lib` and the stem (e.g. `s`,
##                               `d`, `sd`, `-static`). Empty when the
##                               remainder cannot be derived.
## @note Skips directories and `*.pdb`. Skips a hit that is already the
##       exact canonical file `${dir}/${stem}${suffix}`. `lib${stem}${suffix}`
##       remains a valid source toward `${stem}${suffix}`. First match wins.
function(_bm_rename_find_source dir stem suffix out_src out_variant_token)
	set(_found "")
	set(_token "")
	_bm_rename_candidate_names("${stem}" "${suffix}" _patterns)

	foreach(_pat IN LISTS _patterns)
		file(GLOB _hits "${dir}/${_pat}")
		foreach(_f IN LISTS _hits)
			if(IS_DIRECTORY "${_f}")
				continue()
			endif()
			get_filename_component(_bn "${_f}" NAME)
			string(TOLOWER "${_bn}" _bn_l)
			if(_bn_l MATCHES "\\.pdb$")
				continue()
			endif()
			# Skip if already the canonical name we want (caller checks EXISTS first)
			_bm_rename_split_name("${_bn}" _hs _hx)
			if(_hs STREQUAL "${stem}" AND _bn MATCHES "${stem}${suffix}$")
				# exact canonical in glob — ignore
				get_filename_component(_want "${dir}/${stem}${suffix}" ABSOLUTE)
				get_filename_component(_have "${_f}" ABSOLUTE)
				if(_want STREQUAL _have)
					continue()
				endif()
				# lib${stem}${suffix} is a valid source toward ${stem}${suffix}
			endif()
			set(_found "${_f}")
			# variant token = filename without lib prefix and without suffix
			string(REGEX REPLACE "\\${suffix}$" "" _tok "${_bn}")
			if(_tok MATCHES "^[Ll][Ii][Bb](.+)$")
				set(_tok "${CMAKE_MATCH_1}")
			endif()
			# strip base stem prefix to leave variant piece (s, d, sd, …)
			string(LENGTH "${stem}" _slen)
			string(SUBSTRING "${_tok}" 0 ${_slen} _pref)
			if(_pref STREQUAL "${stem}")
				string(SUBSTRING "${_tok}" ${_slen} -1 _token)
			else()
				set(_token "")
			endif()
			break()
		endforeach()
		if(NOT _found STREQUAL "")
			break()
		endif()
	endforeach()

	set(${out_src} "${_found}" PARENT_SCOPE)
	set(${out_variant_token} "${_token}" PARENT_SCOPE)
endfunction()

# ---- main ----

foreach(_out IN LISTS OUTPUTS)
	if(_out STREQUAL "")
		continue()
	endif()
	if(EXISTS "${_out}")
		buildmaster_message(RENAME INFO "rename: ${_out} already present (skip)")
		continue()
	endif()

	get_filename_component(_dir "${_out}" DIRECTORY)
	get_filename_component(_fn "${_out}" NAME)
	_bm_rename_split_name("${_fn}" _stem _suffix)
	if(_stem STREQUAL "" OR _suffix STREQUAL "")
		buildmaster_message(RENAME FATAL "rename: cannot parse stem/suffix from '${_fn}'")
	endif()

	if(NOT IS_DIRECTORY "${_dir}")
		buildmaster_message(RENAME FATAL "rename: directory missing for '${_out}': ${_dir}")
	endif()

	_bm_rename_find_source("${_dir}" "${_stem}" "${_suffix}" _src _vtok)
	if(_src STREQUAL "")
		buildmaster_message(RENAME FATAL
			"rename: no candidate for '${_out}' (stem='${_stem}' suffix='${_suffix}') in ${_dir}")
	endif()

	file(RENAME "${_src}" "${_out}")
	buildmaster_message(RENAME INFO "rename: ${_src} → ${_out}")

	# Windows shared: pair DLL with same variant token
	if(_suffix STREQUAL ".lib" AND NOT BINDIR STREQUAL "")
		set(_dll_dst "${BINDIR}/${_stem}.dll")
		if(NOT EXISTS "${_dll_dst}")
			set(_dll_src "")
			if(NOT _vtok STREQUAL "")
				if(EXISTS "${BINDIR}/${_stem}${_vtok}.dll")
					set(_dll_src "${BINDIR}/${_stem}${_vtok}.dll")
				elseif(EXISTS "${_dir}/${_stem}${_vtok}.dll")
					set(_dll_src "${_dir}/${_stem}${_vtok}.dll")
				endif()
			endif()
			if(_dll_src STREQUAL "")
				_bm_rename_find_source("${BINDIR}" "${_stem}" ".dll" _dll_src _dll_tok)
				if(_dll_src STREQUAL "" AND IS_DIRECTORY "${_dir}")
					_bm_rename_find_source("${_dir}" "${_stem}" ".dll" _dll_src _dll_tok)
				endif()
			endif()
			if(NOT _dll_src STREQUAL "" AND NOT EXISTS "${_dll_dst}")
				file(RENAME "${_dll_src}" "${_dll_dst}")
				buildmaster_message(RENAME INFO "rename: ${_dll_src} → ${_dll_dst}")
			endif()
		endif()
	endif()
endforeach()
