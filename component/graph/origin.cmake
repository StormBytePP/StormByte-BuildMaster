# =============================================================================
# component/graph/origin.cmake — first-declaration file:line for every id
# =============================================================================
# Stamp ONLY from public macros. A function()'s CMAKE_CURRENT_LIST_FILE
# is this repo, which is useless to the user. The macro passes the
# caller's file and line.

## @brief Record where `id` was first declared, if not already stamped.
## @param[in] id   Component, meta, or group id.
## @param[in] kind `component`, `meta`, or `group`.
## @param[in] file Caller's `CMAKE_CURRENT_LIST_FILE` (from a public macro).
## @param[in] line Caller's `CMAKE_CURRENT_LIST_LINE`.
## @note Second stamp of the same id+kind is a no-op (first wins).
##       Same id, different kind → FATAL with the first origin.
function(_bm_id_stamp id kind file line)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_id_stamp")
	if("${id}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_id_stamp")
		return()
	endif()
	get_property(_have GLOBAL PROPERTY BUILDMASTER_ID_${id}_ORIGIN)
	get_property(_oldk GLOBAL PROPERTY BUILDMASTER_ID_${id}_KIND)
	if(NOT "${_have}" STREQUAL "")
		if(NOT "${_oldk}" STREQUAL "${kind}")
			_bm_id_clash_fatal("id stamp (${kind})" "${id}")
		endif()
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_id_stamp")
		return()
	endif()
	if("${file}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_id_stamp")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_ID_${id}_KIND "${kind}")
	set_property(GLOBAL PROPERTY BUILDMASTER_ID_${id}_ORIGIN "${file}:${line}")
	_bm_log_message(COMPONENT DEBUG "id '${id}' (${kind}) at ${file}:${line}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_id_stamp")
endfunction()

## @brief Kind last stamped for `id` (`component` / `meta` / `group` / empty).
## @param[in]  id      Identifier.
## @param[out] out_var Parent-scope string.
function(_bm_id_kind id out_var)
	get_property(_k GLOBAL PROPERTY BUILDMASTER_ID_${id}_KIND)
	set(${out_var} "${_k}" PARENT_SCOPE)
endfunction()

## @brief `file:line` of the first stamp, or empty.
## @param[in]  id      Identifier.
## @param[out] out_var Parent-scope string.
function(_bm_id_origin id out_var)
	get_property(_o GLOBAL PROPERTY BUILDMASTER_ID_${id}_ORIGIN)
	set(${out_var} "${_o}" PARENT_SCOPE)
endfunction()

## @brief Suffix ` (file:line)` when origin is known, else empty.
## @param[in]  id      Identifier.
## @param[out] out_var Parent-scope string (leading space included).
function(_bm_id_origin_suffix id out_var)
	_bm_id_origin("${id}" _o)
	if("${_o}" STREQUAL "")
		set(${out_var} "" PARENT_SCOPE)
	else()
		set(${out_var} " (${_o})" PARENT_SCOPE)
	endif()
endfunction()

## @brief FATAL: `cmd('id'): id already used as a <kind> (file:line)`.
## @param[in] cmd  Command name for the message.
## @param[in] id   Conflicting id.
function(_bm_id_clash_fatal cmd id)
	_bm_id_kind("${id}" _kind)
	_bm_id_origin_suffix("${id}" _at)
	if("${_kind}" STREQUAL "")
		set(_kind "id")
	endif()
	_bm_log_message(COMPONENT FATAL
		"${cmd}('${id}'): id already used as a ${_kind}${_at}")
endfunction()
