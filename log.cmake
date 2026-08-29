# BuildMaster logging. Only file allowed to call CMake message().

## @brief Load level/module tables into GLOBAL properties (visible from DEFER).
## @note Directory-scope `set()` is invisible in the parent CMAKE_SOURCE_DIR
##       where cmake_language(DEFER) runs after add_subdirectory(buildmaster).
##       This function is idempotent and is the single source of the tables.
function(_buildmaster_log_ensure_registry)
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

_buildmaster_log_ensure_registry()

## @brief Pad or truncate `_text` to `_width` (spaces on the right).
## @param[out] _out   Parent-scope padded string.
## @param[in]  _text  Source text.
## @param[in]  _width Target width in characters.
## @note Used so [LEVEL] and [BuildMaster/Module] columns stay aligned.
function(_buildmaster_log_pad _out _text _width)
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

## @brief Resolve a level name or 0-5 integer to a canonical uppercase name.
## @param[out] _out Parent-scope canonical level (LOWLEVEL, DEBUG, INFO,
##                  WARNING, STATUS, or FATAL).
## @param[in]  _raw Name or integer as provided by cache, env, or caller.
## @note Accepts the six names (any case) or the integers 0–5. Anything else
##       is FATAL and lists the accepted names. Used both for
##       BUILDMASTER_LOGLEVEL and for the level argument of
##       buildmaster_message().
function(_buildmaster_log_parse_level _out _raw)
	_buildmaster_log_ensure_registry()
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
function(buildmaster_loglevel_init)
	set(_raw "")
	if(DEFINED BUILDMASTER_LOGLEVEL AND NOT "${BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_raw "${BUILDMASTER_LOGLEVEL}")
	elseif(DEFINED ENV{BUILDMASTER_LOGLEVEL} AND NOT "$ENV{BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_raw "$ENV{BUILDMASTER_LOGLEVEL}")
	endif()
	if(_raw STREQUAL "")
		set(_raw "STATUS")
	endif()
	_buildmaster_log_parse_level(_canon "${_raw}")
	set(BUILDMASTER_LOGLEVEL "${_canon}" PARENT_SCOPE)
endfunction()

## @brief STATUS-style header used by Ninja COMMENT (no level tag).
## @param[out] _out    Parent-scope string `[BuildMaster/<Mod>]: <text>`
## @param[in]  _module Uppercase module key (CMAKE, MESON, USER, …).
## @param[in]  _text   Comment body.
## @note Matches the STATUS layout of buildmaster_message() so configure
##       lines and ninja progress share one column. Unknown modules FATAL.
function(buildmaster_log_comment _out _module _text)
	_buildmaster_log_ensure_registry()
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
	_buildmaster_log_pad(_modp "${_lab}" ${_pad})
	set(${_out} "[BuildMaster/${_modp}]: ${_text}" PARENT_SCOPE)
endfunction()

## @brief Unified BuildMaster log line.
## @param[in] _module Module tag (`BUILDMASTER_LOG_MODULES`). Use USER from parent projects.
## @param[in] _level  LOWLEVEL, DEBUG, INFO, WARNING, STATUS, or FATAL.
## @param[in] _message Text after the header.
## @param[in] _indent Optional tab count after the header (default 0).
## @note FATAL and WARNING are never filtered. Default `BUILDMASTER_LOGLEVEL`
##       is STATUS: STATUS + WARNING + FATAL are visible; INFO / DEBUG /
##       LOWLEVEL are not. Setting the filter to INFO (or lower) reveals
##       those. STATUS lines have no [LEVEL] tag. Header is never indented.
## @note WARNING without `BUILDMASTER_VERBOSE`: one `message(NOTICE)` line
##       on stderr, yellow/bold (CMake warning colour), no `CMake Warning
##       at …` banner. With `BUILDMASTER_VERBOSE` ON: `message(WARNING)`.
## @note FATAL stays `message(FATAL_ERROR)`.
## @note This file is the only BuildMaster source allowed to call message().
## @note Tables live in GLOBAL properties so deferred finalize in the parent
##       CMAKE_SOURCE_DIR (consumer add_subdirectory pattern) still resolves
##       modules such as COMPONENT.
function(buildmaster_message _module _level _message)
	_buildmaster_log_ensure_registry()
	if(ARGC LESS 3 OR ARGC GREATER 4)
		message(FATAL_ERROR
			"[BuildMaster/Core]: buildmaster_message requires module, level, message and optional indent")
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

	_buildmaster_log_parse_level(_lvl "${_level}")

	if(NOT DEFINED BUILDMASTER_LOGLEVEL OR "${BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_cur "STATUS")
	else()
		_buildmaster_log_parse_level(_cur "${BUILDMASTER_LOGLEVEL}")
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
	_buildmaster_log_pad(_modp "${_lab}" ${_pad_mod})
	_buildmaster_log_pad(_lvlp "${_lvl}" ${_pad_lvl})

	if(_lvl STREQUAL "STATUS")
		set(_line "[BuildMaster/${_modp}]: ${_tabs}${_message}")
	else()
		set(_line "[${_lvlp}][BuildMaster/${_modp}]: ${_tabs}${_message}")
	endif()

	if(_lvl STREQUAL "FATAL")
		message(FATAL_ERROR "${_line}")
	elseif(_lvl STREQUAL "WARNING")
		if(BUILDMASTER_VERBOSE)
			message(WARNING "${_line}")
		else()
			string(ASCII 27 _esc)
			message(NOTICE "${_esc}[1;33m${_line}${_esc}[0m")
		endif()
	else()
		message(STATUS "${_line}")
	endif()
endfunction()
