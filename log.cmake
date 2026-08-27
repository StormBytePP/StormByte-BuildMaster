# BuildMaster logging. Only file allowed to call CMake message().

set(_BM_LOG_LEVELS "LOWLEVEL;DEBUG;INFO;WARNING;STATUS;FATAL")
set(_BM_LOG_LEVEL_LOWLEVEL 0)
set(_BM_LOG_LEVEL_DEBUG 1)
set(_BM_LOG_LEVEL_INFO 2)
set(_BM_LOG_LEVEL_WARNING 3)
set(_BM_LOG_LEVEL_STATUS 4)
set(_BM_LOG_LEVEL_FATAL 5)

# API key → visible CamelCase label
set(_BM_LOG_MOD_ARCHIVE "Archive")
set(_BM_LOG_MOD_BUNDLE "Bundle")
set(_BM_LOG_MOD_CMAKE "CMake")
set(_BM_LOG_MOD_COMPONENT "Component")
set(_BM_LOG_MOD_CORE "Core")
set(_BM_LOG_MOD_ENV "Env")
set(_BM_LOG_MOD_EXTRA "Extra")
set(_BM_LOG_MOD_FILE "File")
set(_BM_LOG_MOD_GIT "Git")
set(_BM_LOG_MOD_MESON "Meson")
set(_BM_LOG_MOD_META "Meta")
set(_BM_LOG_MOD_NINJA "Ninja")
set(_BM_LOG_MOD_PKGCONF "Pkgconf")
set(_BM_LOG_MOD_RENAME "Rename")
set(_BM_LOG_MOD_REPACK "Repack")
set(_BM_LOG_MOD_TOOLCHAIN "Toolchain")
set(_BM_LOG_MOD_TOOLS "Tools")
# USER is reserved for parent / consumer projects (not an internal BM module).
set(_BM_LOG_MOD_USER "User")
set(_BM_LOG_MODULES "ARCHIVE;BUNDLE;CMAKE;COMPONENT;CORE;ENV;EXTRA;FILE;GIT;MESON;META;NINJA;PKGCONF;RENAME;REPACK;TOOLCHAIN;TOOLS;USER")

set(_BM_LOG_PAD_LEVEL 0)
foreach(_bm_n IN LISTS _BM_LOG_LEVELS)
	string(LENGTH "${_bm_n}" _bm_l)
	if(_bm_l GREATER _BM_LOG_PAD_LEVEL)
		set(_BM_LOG_PAD_LEVEL ${_bm_l})
	endif()
endforeach()

set(_BM_LOG_PAD_MODULE 0)
foreach(_bm_k IN LISTS _BM_LOG_MODULES)
	set(_bm_lab "${_BM_LOG_MOD_${_bm_k}}")
	string(LENGTH "${_bm_lab}" _bm_l)
	if(_bm_l GREATER _BM_LOG_PAD_MODULE)
		set(_BM_LOG_PAD_MODULE ${_bm_l})
	endif()
endforeach()

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
	list(FIND _BM_LOG_LEVELS "${_v}" _idx)
	if(_idx EQUAL -1)
		string(REPLACE ";" ", " _acc "${_BM_LOG_LEVELS}")
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
	string(TOUPPER "${_module}" _mod)
	list(FIND _BM_LOG_MODULES "${_mod}" _midx)
	if(_midx EQUAL -1)
		string(REPLACE ";" ", " _acc "${_BM_LOG_MODULES}")
		message(FATAL_ERROR
			"[BuildMaster/Core]: unknown log module '${_module}'. Accepted: ${_acc}")
	endif()
	set(_lab "${_BM_LOG_MOD_${_mod}}")
	_buildmaster_log_pad(_modp "${_lab}" ${_BM_LOG_PAD_MODULE})
	set(${_out} "[BuildMaster/${_modp}]: ${_text}" PARENT_SCOPE)
endfunction()

## @brief Unified BuildMaster log line.
## @param[in] _module Module tag (`_BM_LOG_MODULES`). Use USER from parent projects.
## @param[in] _level  LOWLEVEL, DEBUG, INFO, WARNING, STATUS, or FATAL.
## @param[in] _message Text after the header.
## @param[in] _indent Optional tab count after the header (default 0).
## @note FATAL is never filtered. WARNING is hidden when current > INFO.
##       STATUS lines have no [LEVEL] tag. Header is never indented.
## @note This file is the only BuildMaster source allowed to call message().
function(buildmaster_message _module _level _message)
	if(ARGC LESS 3 OR ARGC GREATER 4)
		message(FATAL_ERROR
			"[BuildMaster/Core]: buildmaster_message requires module, level, message and optional indent")
	endif()

	string(TOUPPER "${_module}" _mod)
	string(STRIP "${_mod}" _mod)
	list(FIND _BM_LOG_MODULES "${_mod}" _midx)
	if(_midx EQUAL -1)
		string(REPLACE ";" ", " _acc "${_BM_LOG_MODULES}")
		message(FATAL_ERROR
			"[BuildMaster/Core]: unknown log module '${_module}'. Accepted: ${_acc}")
	endif()

	_buildmaster_log_parse_level(_lvl "${_level}")

	if(NOT DEFINED BUILDMASTER_LOGLEVEL OR "${BUILDMASTER_LOGLEVEL}" STREQUAL "")
		set(_cur "STATUS")
	else()
		_buildmaster_log_parse_level(_cur "${BUILDMASTER_LOGLEVEL}")
	endif()

	set(_n_msg ${_BM_LOG_LEVEL_${_lvl}})
	set(_n_cur ${_BM_LOG_LEVEL_${_cur}})

	if(NOT _lvl STREQUAL "FATAL")
		if(_n_msg LESS _n_cur)
			return()
		endif()
		if(_lvl STREQUAL "WARNING" AND _n_cur GREATER ${_BM_LOG_LEVEL_INFO})
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

	set(_lab "${_BM_LOG_MOD_${_mod}}")
	_buildmaster_log_pad(_modp "${_lab}" ${_BM_LOG_PAD_MODULE})
	_buildmaster_log_pad(_lvlp "${_lvl}" ${_BM_LOG_PAD_LEVEL})

	if(_lvl STREQUAL "STATUS")
		set(_line "[BuildMaster/${_modp}]: ${_tabs}${_message}")
	else()
		set(_line "[${_lvlp}][BuildMaster/${_modp}]: ${_tabs}${_message}")
	endif()

	if(_lvl STREQUAL "FATAL")
		message(FATAL_ERROR "${_line}")
	elseif(_lvl STREQUAL "WARNING")
		message(WARNING "${_line}")
	else()
		message(STATUS "${_line}")
	endif()
endfunction()
