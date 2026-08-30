# BuildMaster logging. Only file allowed to call CMake message().

## @brief Load level/module tables into GLOBAL properties (visible from DEFER).
## @note Directory-scope `set()` is invisible in the parent CMAKE_SOURCE_DIR
##       where cmake_language(DEFER) runs after add_subdirectory(buildmaster).
##       This function is idempotent and is the single source of the tables.
function(_bm_log_ensure_registry)
	get_property(_have GLOBAL PROPERTY BUILDMASTER_LOG_MODULES SET)
	if(_have)
		get_property(_mods GLOBAL PROPERTY BUILDMASTER_LOG_MODULES)
		list(FIND _mods "COMPONENT" _idx)
		if(NOT _idx EQUAL -1)
			return()
		endif()
	endif()

	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVELS
		"LOWLEVEL;DEBUG;INFO;WARNING;STATUS;FATAL")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_LOWLEVEL 0)
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_DEBUG 1)
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_INFO 2)
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_WARNING 3)
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_STATUS 4)
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_FATAL 5)

	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_ARCHIVE "Archive")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_BUNDLE "Bundle")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_CMAKE "CMake")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_COMPONENT "Component")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_CORE "Core")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_ENV "Env")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_EXTRA "Extra")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_FILE "File")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_GIT "Git")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_MESON "Meson")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_META "Meta")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_NINJA "Ninja")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_PKGCONF "Pkgconf")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_RENAME "Rename")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_REPACK "Repack")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_TOOLCHAIN "Toolchain")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_TOOLS "Tools")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MOD_USER "User")
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_MODULES
		"ARCHIVE;BUNDLE;CMAKE;COMPONENT;CORE;ENV;EXTRA;FILE;GIT;MESON;META;NINJA;PKGCONF;RENAME;REPACK;TOOLCHAIN;TOOLS;USER")

	set(_pad_level 0)
	get_property(_levels GLOBAL PROPERTY BUILDMASTER_LOG_LEVELS)
	foreach(_bm_n IN LISTS _levels)
		string(LENGTH "${_bm_n}" _bm_l)
		if(_bm_l GREATER _pad_level)
			set(_pad_level ${_bm_l})
		endif()
	endforeach()
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_PAD_LEVEL "${_pad_level}")

	set(_pad_mod 0)
	get_property(_mods GLOBAL PROPERTY BUILDMASTER_LOG_MODULES)
	foreach(_bm_k IN LISTS _mods)
		get_property(_bm_lab GLOBAL PROPERTY BUILDMASTER_LOG_MOD_${_bm_k})
		string(LENGTH "${_bm_lab}" _bm_l)
		if(_bm_l GREATER _pad_mod)
			set(_pad_mod ${_bm_l})
		endif()
	endforeach()
	set_property(GLOBAL PROPERTY BUILDMASTER_LOG_PAD_MODULE "${_pad_mod}")
endfunction()

_bm_log_ensure_registry()

## @brief Pad or truncate `_text` to `_width` (spaces on the right).
## @param[out] _out   Parent-scope padded string.
## @param[in]  _text  Source text.
## @param[in]  _width Target width in characters.
## @note Used so [LEVEL] and [BuildMaster/Module] columns stay aligned.
function(_bm_log_pad _out _text _width)
	set(_t "${_text}")
	string(LENGTH "${_t}" _n)
	if(_n GREATER _width)
		string(SUBSTRING "${_t}" 0 ${_width} _t)
	elseif(_n LESS _width)
		math(EXPR _pad "${_width} - ${_n}")
		string(REPEAT " " ${_pad} _sp)
		set(_t "${_t}${_sp}")
	endif()
	set(${_out} "${_t}" PARENT_SCOPE)
endfunction()

## @brief Whether ANSI color is allowed on this log line.
## @param[out] _out Parent-scope TRUE / FALSE.
## @note Driven by BUILDMASTER_LOG_NOCOLOR (ON/OFF). Default OFF = color on.
##       Set via -DBUILDMASTER_LOG_NOCOLOR=ON or ENV{BUILDMASTER_LOG_NOCOLOR}
##       (1 / ON / TRUE / YES). A -P script that never ran init_vars reads
##       the ENV the same way and stores ON/OFF in BUILDMASTER_LOG_NOCOLOR.
function(_bm_log_color_enabled _out)
	if(NOT DEFINED BUILDMASTER_LOG_NOCOLOR OR "${BUILDMASTER_LOG_NOCOLOR}" STREQUAL "")
		set(_raw "")
		if(DEFINED ENV{BUILDMASTER_LOG_NOCOLOR})
			set(_raw "$ENV{BUILDMASTER_LOG_NOCOLOR}")
		endif()
		string(TOUPPER "${_raw}" _raw)
		if(_raw STREQUAL "1"
				OR _raw STREQUAL "ON"
				OR _raw STREQUAL "TRUE"
				OR _raw STREQUAL "YES")
			set(BUILDMASTER_LOG_NOCOLOR ON)
		else()
			set(BUILDMASTER_LOG_NOCOLOR OFF)
		endif()
	endif()
	if(BUILDMASTER_LOG_NOCOLOR)
		set(${_out} FALSE PARENT_SCOPE)
	else()
		set(${_out} TRUE PARENT_SCOPE)
	endif()
endfunction()

## @brief Wrap `_text` in an ANSI SGR sequence when color is on.
## @param[out] _out  Parent-scope painted string.
## @param[in]  _sgr  Codes after CSI (e.g. `36`, `1;31`). Empty → no wrap.
## @param[in]  _text Plain line.
function(_bm_log_paint _out _sgr _text)
	if("${_sgr}" STREQUAL "")
		set(${_out} "${_text}" PARENT_SCOPE)
		return()
	endif()
	_bm_log_color_enabled(_on)
	if(NOT _on)
		set(${_out} "${_text}" PARENT_SCOPE)
		return()
	endif()
	string(ASCII 27 _esc)
	set(${_out} "${_esc}[${_sgr}m${_text}${_esc}[0m" PARENT_SCOPE)
endfunction()

## @brief Resolve a level name or 0-5 integer to a canonical uppercase name.
## @param[out] _out Parent-scope canonical level (LOWLEVEL, DEBUG, INFO,
##                  WARNING, STATUS, or FATAL).
## @param[in]  _raw Name or integer as provided by cache, env, or caller.
## @note Accepts the six names (any case) or the integers 0–5. Anything else
##       is FATAL and lists the accepted names. Used for BUILDMASTER_LOGLEVEL
##       and for the level argument of `_bm_log_message` /
##       `buildmaster_message`.
function(_bm_log_parse_level _out _raw)
	_bm_log_ensure_registry()
	set(_v "${_raw}")
	string(TOUPPER "${_v}" _v)
	string(STRIP "${_v}" _v)
	if(_v STREQUAL "0")
		set(_v "LOWLEVEL")
	elseif(_v STREQUAL "1")
		set(_v "DEBUG")
	elseif(_v STREQUAL "2")
		set(_v "INFO")
	elseif(_v STREQUAL "3")
		set(_v "WARNING")
	elseif(_v STREQUAL "4")
		set(_v "STATUS")
	elseif(_v STREQUAL "5")
		set(_v "FATAL")
	endif()
	get_property(_levels GLOBAL PROPERTY BUILDMASTER_LOG_LEVELS)
	list(FIND _levels "${_v}" _idx)
	if(_idx EQUAL -1)
		string(REPLACE ";" ", " _acc "${_levels}")
		message(FATAL_ERROR
			"[BuildMaster/Core]: invalid BUILDMASTER_LOGLEVEL '${_raw}'. Accepted: ${_acc}")
	endif()
	set(${_out} "${_v}" PARENT_SCOPE)
endfunction()

## @brief Read cache/env, validate, and set BUILDMASTER_LOGLEVEL in the caller.
## @note Precedence: CMake cache/variable BUILDMASTER_LOGLEVEL, then
##       ENV{BUILDMASTER_LOGLEVEL}, then STATUS. Empty values are ignored.
## @note BUILDMASTER_DEBUG (cache and env) is ignored; it is not a log level.
## @note Must run in -P scripts after include(log.cmake) so generated stages
##       see the same filter as parent configure. Writes PARENT_SCOPE only.
function(_bm_log_level_init)
	set(_raw "")
	if(DEFINED BUILDMASTER_LOGLEVEL AND NOT "${BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_raw "${BUILDMASTER_LOGLEVEL}")
	elseif(DEFINED ENV{BUILDMASTER_LOGLEVEL} AND NOT "$ENV{BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_raw "$ENV{BUILDMASTER_LOGLEVEL}")
	endif()
	if(_raw STREQUAL "")
		set(_raw "STATUS")
	endif()
	_bm_log_parse_level(_canon "${_raw}")
	set(BUILDMASTER_LOGLEVEL "${_canon}" PARENT_SCOPE)
endfunction()

## @brief STATUS-style header used by Ninja COMMENT (no level tag).
## @param[out] _out    Parent-scope string `[BuildMaster/<Mod>]: <text>`
## @param[in]  _module Uppercase module key (CMAKE, MESON, USER, …).
## @param[in]  _text   Comment body.
## @note Matches the STATUS layout of `_bm_log_message` /
##       `buildmaster_message` so configure lines and ninja progress share
##       one column. Unknown modules FATAL. Not colored (Ninja COMMENT).
function(_bm_log_comment _out _module _text)
	_bm_log_ensure_registry()
	string(TOUPPER "${_module}" _mod)
	get_property(_mods GLOBAL PROPERTY BUILDMASTER_LOG_MODULES)
	list(FIND _mods "${_mod}" _midx)
	if(_midx EQUAL -1)
		string(REPLACE ";" ", " _acc "${_mods}")
		message(FATAL_ERROR
			"[BuildMaster/Core]: unknown log module '${_module}'. Accepted: ${_acc}")
	endif()
	get_property(_lab GLOBAL PROPERTY BUILDMASTER_LOG_MOD_${_mod})
	get_property(_pad GLOBAL PROPERTY BUILDMASTER_LOG_PAD_MODULE)
	_bm_log_pad(_modp "${_lab}" ${_pad})
	set(${_out} "[BuildMaster/${_modp}]: ${_text}" PARENT_SCOPE)
endfunction()

## @brief Unified BuildMaster log line (internal).
## @param[in] _module Module tag (`BUILDMASTER_LOG_MODULES`).
## @param[in] _level  LOWLEVEL, DEBUG, INFO, WARNING, STATUS, or FATAL.
## @param[in] _message Text after the header.
## @param[in] _indent Optional tab count after the header (default 0).
## @note Not public. Parent projects call `buildmaster_message`.
## @note Color (when BUILDMASTER_LOG_NOCOLOR is OFF):
##       STATUS plain; WARNING yellow `1;33`; INFO green `32`; DEBUG
##       cyan `36`; LOWLEVEL dim `2;37`; FATAL red `1;31`.
## @note BUILDMASTER_VERBOSE does not change how WARNING is emitted.
##       It only selects nested compile `--verbose` / `-v`.
function(_bm_log_message _module _level _message)
	_bm_log_ensure_registry()
	if(ARGC LESS 3 OR ARGC GREATER 4)
		message(FATAL_ERROR
			"[BuildMaster/Core]: _bm_log_message requires module, level, message and optional indent")
	endif()

	string(TOUPPER "${_module}" _mod)
	string(STRIP "${_mod}" _mod)
	get_property(_mods GLOBAL PROPERTY BUILDMASTER_LOG_MODULES)
	list(FIND _mods "${_mod}" _midx)
	if(_midx EQUAL -1)
		string(REPLACE ";" ", " _acc "${_mods}")
		message(FATAL_ERROR
			"[BuildMaster/Core]: unknown log module '${_module}'. Accepted: ${_acc}")
	endif()

	_bm_log_parse_level(_lvl "${_level}")

	if(NOT DEFINED BUILDMASTER_LOGLEVEL OR "${BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_cur "STATUS")
	else()
		_bm_log_parse_level(_cur "${BUILDMASTER_LOGLEVEL}")
	endif()

	get_property(_n_msg GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_${_lvl})
	get_property(_n_cur GLOBAL PROPERTY BUILDMASTER_LOG_LEVEL_${_cur})

	if(NOT _lvl STREQUAL "FATAL" AND NOT _lvl STREQUAL "WARNING")
		if(_n_msg LESS _n_cur)
			return()
		endif()
	endif()

	set(_tabs "")
	if(ARGC EQUAL 4)
		set(_nindent "${ARGV3}")
		if(_nindent MATCHES "^[0-9]+$")
			if(_nindent GREATER 0)
				string(REPEAT "	" ${_nindent} _tabs)
			endif()
		endif()
	endif()

	get_property(_lab GLOBAL PROPERTY BUILDMASTER_LOG_MOD_${_mod})
	get_property(_pad_mod GLOBAL PROPERTY BUILDMASTER_LOG_PAD_MODULE)
	get_property(_pad_lvl GLOBAL PROPERTY BUILDMASTER_LOG_PAD_LEVEL)
	_bm_log_pad(_modp "${_lab}" ${_pad_mod})
	_bm_log_pad(_lvlp "${_lvl}" ${_pad_lvl})

	if(_lvl STREQUAL "STATUS")
		set(_line "[BuildMaster/${_modp}]: ${_tabs}${_message}")
	else()
		set(_line "[${_lvlp}][BuildMaster/${_modp}]: ${_tabs}${_message}")
	endif()

	if(_lvl STREQUAL "FATAL")
		_bm_log_paint(_line "1;31" "${_line}")
		message(FATAL_ERROR "${_line}")
	elseif(_lvl STREQUAL "WARNING")
		_bm_log_paint(_line "1;33" "${_line}")
		message(NOTICE "${_line}")
	elseif(_lvl STREQUAL "DEBUG")
		_bm_log_paint(_line "36" "${_line}")
		message(STATUS "${_line}")
	elseif(_lvl STREQUAL "INFO")
		_bm_log_paint(_line "32" "${_line}")
		message(STATUS "${_line}")
	elseif(_lvl STREQUAL "LOWLEVEL")
		_bm_log_paint(_line "2;37" "${_line}")
		message(STATUS "${_line}")
	else()
		message(STATUS "${_line}")
	endif()
endfunction()

## @brief Public log line for parent projects.
## @param[in] _level   LOWLEVEL, DEBUG, INFO, WARNING, STATUS, or FATAL.
## @param[in] _message Text after the header.
## @param[in] _indent  Optional tab count after the header (default 0).
## @note Module is always USER. It cannot be overridden.
## @note Color follows `_bm_log_message` / BUILDMASTER_LOG_NOCOLOR.
function(buildmaster_message _level _message)
	if(ARGC LESS 2 OR ARGC GREATER 3)
		message(FATAL_ERROR
			"[BuildMaster/Core]: buildmaster_message requires level, message and optional indent")
	endif()
	if(ARGC EQUAL 3)
		_bm_log_message(USER "${_level}" "${_message}" "${ARGV2}")
	else()
		_bm_log_message(USER "${_level}" "${_message}")
	endif()
endfunction()
