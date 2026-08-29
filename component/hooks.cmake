# =============================================================================
# component/hooks.cmake — inspectable materialize / graph-finalize hooks
# =============================================================================

## @brief Serialize one registrar variable into a `set()` line for the template.
## @param[out] _out  Parent-scope `set(NAME [=[value]=])` line, no newline.
## @param[in]  _name Variable name to read from the current scope.
## @note Copy at call time. Undefined names become `set(NAME "")`.
##       A value that contains `]=]` is FATAL (bracket form would break).
function(_buildmaster_hook_capture_line _out _name)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_hook_capture_line")
	if(NOT DEFINED ${_name})
		set(${_out} "set(${_name} \"\")" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_hook_capture_line")
		return()
	endif()
	set(_val "${${_name}}")
	if(_val MATCHES "\\]=\\]")
		_bm_log_message(COMPONENT FATAL
			"hook CAPTURE '${_name}': value contains ']=]' and cannot be snapshotted")
	endif()
	set(${_out} "set(${_name} [=[${_val}]=])" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_hook_capture_line")
endfunction()

## @brief Write one hook script and append `alias|path` to a global list.
## @param[in] _list_prop  Global property that stores `alias|path` pairs.
## @param[in] _kind       `component` or `graph` (filename + template tag).
## @param[in] _alias      Order key; sanitized for the filename prefix.
## @param[in] _function   CMake function name written into the script.
## @param[in] _component  Component id, or empty for graph hooks.
## @param[in] _captures   Variable names to snapshot (may be empty).
## @note Path:
##       `${BUILDMASTER_SCRIPTS_HOOK_DIR}/<alias>__component_<id>.cmake` or
##       `${BUILDMASTER_SCRIPTS_HOOK_DIR}/<alias>__graph.cmake`.
##       Duplicate alias in `_list_prop` is FATAL. Empty sanitized alias
##       is FATAL.
function(_buildmaster_hook_write _list_prop _kind _alias _function _component _captures)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_hook_write")
	sanitize_for_filename(_safe_alias "${_alias}")
	if("${_safe_alias}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"hook alias '${_alias}' sanitizes to an empty filename")
	endif()
	if(_kind STREQUAL "component")
		sanitize_for_filename(_safe_id "${_component}")
		set(_file "${BUILDMASTER_SCRIPTS_HOOK_DIR}/${_safe_alias}__component_${_safe_id}.cmake")
	else()
		set(_file "${BUILDMASTER_SCRIPTS_HOOK_DIR}/${_safe_alias}__graph.cmake")
	endif()

	set(HOOK_KIND "${_kind}")
	set(HOOK_ALIAS "${_alias}")
	set(HOOK_FUNCTION "${_function}")
	set(HOOK_COMPONENT "${_component}")
	set(HOOK_CAPTURES "")
	foreach(_n IN LISTS _captures)
		if("${_n}" STREQUAL "")
			_bm_log_message(COMPONENT FATAL
				"hook CAPTURE: empty variable name")
		endif()
		_buildmaster_hook_capture_line(_line "${_n}")
		string(APPEND HOOK_CAPTURES "${_line}\n")
	endforeach()

	configure_file(
		"${BUILDMASTER_COMPONENT_TEMPLATEDIR}/hook.cmake.in"
		"${_file}"
		@ONLY
	)

	get_property(_pairs GLOBAL PROPERTY ${_list_prop})
	foreach(_pair IN LISTS _pairs)
		string(REGEX REPLACE "\\|.*$" "" _exist "${_pair}")
		if(_exist STREQUAL "${_alias}")
			_bm_log_message(COMPONENT FATAL
				"hook alias '${_alias}' already registered in this scope")
		endif()
	endforeach()
	set_property(GLOBAL APPEND PROPERTY ${_list_prop} "${_alias}|${_file}")
	_bm_log_message(COMPONENT DEBUG "Wrote hook script ${_file}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_hook_write")
endfunction()

## @brief Include hook scripts for one property, aliases sorted ASCII ascending.
## @param[in] _list_prop Global property of `alias|path` pairs.
## @note Order is the alias only. Registration order and graph order are
##       not a contract. A missing script file is FATAL.
function(_buildmaster_hook_run_sorted _list_prop)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_hook_run_sorted")
	get_property(_pairs GLOBAL PROPERTY ${_list_prop})
	if(NOT _pairs)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_hook_run_sorted")
		return()
	endif()
	set(_aliases "")
	foreach(_pair IN LISTS _pairs)
		string(REGEX REPLACE "\\|.*$" "" _a "${_pair}")
		list(APPEND _aliases "${_a}")
	endforeach()
	list(SORT _aliases)
	foreach(_a IN LISTS _aliases)
		set(_file "")
		foreach(_pair IN LISTS _pairs)
			string(REGEX REPLACE "\\|.*$" "" _pa "${_pair}")
			if(_pa STREQUAL "${_a}")
				string(REGEX REPLACE "^[^|]*\\|" "" _file "${_pair}")
				break()
			endif()
		endforeach()
		if(NOT EXISTS "${_file}")
			_bm_log_message(COMPONENT FATAL
				"hook script missing: ${_file}")
		endif()
		include("${_file}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_hook_run_sorted")
endfunction()

## @brief Register a hook that runs after one concrete component materializes.
## @param[in] _component Component id (`create_*_component`).
## @param[in] _function  CMake function name. Must exist now (`COMMAND`).
## @param[in] _alias     Order key (ASCII ascending within this id). Required.
## @param[in] CAPTURE    Optional names snapshotted now into the generated
##            script as `set(NAME [=[value]=])`. Copy, not reference.
##            Values after this call are not seen.
## @note Missing `_function` is a friendly FATAL (no CMake COMMAND stack).
##       The component id may be created later; if it is never materialized
##       (unknown id or meta-only), finalize is FATAL.
## @note No order contract except alias sort within this id. Graph hooks
##       run in a later phase, after every concrete materialize.
## @note Script:
##       `${BUILDMASTER_SCRIPTS_HOOK_DIR}/<alias>__component_<id>.cmake`.
## @note The callback must not call `create_*` or graph mutators
##       (`BUILDMASTER_COMPONENTS_FINALIZED` is already set).
function(buildmaster_on_component_materialize _component _function _alias)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_on_component_materialize")
	cmake_parse_arguments(ARG "" "" "CAPTURE" ${ARGN})
	if(ARG_UNPARSED_ARGUMENTS)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_component_materialize: unexpected arguments (${ARG_UNPARSED_ARGUMENTS})")
	endif()
	if("${_component}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_component_materialize: empty component id")
	endif()
	if("${_function}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_component_materialize: empty function name")
	endif()
	if("${_alias}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_component_materialize: empty alias")
	endif()
	if(NOT COMMAND "${_function}")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_component_materialize('${_component}'): function '${_function}' does not exist yet")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_component_materialize: called after finalize")
	endif()

	_buildmaster_hook_write(
		"BUILDMASTER_ON_MATERIALIZE_${_component}"
		"component"
		"${_alias}"
		"${_function}"
		"${_component}"
		"${ARG_CAPTURE}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_ON_MATERIALIZE_IDS
		"${_component}")
	_buildmaster_component_defer_arm()
	_bm_log_message(COMPONENT DEBUG
		"on_component_materialize ${_component} alias=${_alias} → ${_function}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_on_component_materialize")
endfunction()

## @brief Register a hook that runs after the whole component graph materializes.
## @param[in] _function CMake function name. Must exist now (`COMMAND`).
## @param[in] _alias    Order key (ASCII ascending among graph hooks). Required.
## @param[in] CAPTURE   Optional names snapshotted now (copy). Empty CAPTURE
##            keyword with no names is FATAL inside `_buildmaster_hook_write`
##            only when a blank name is listed.
## @note Runs after git flush, metas, cmake/meson, repacks, links and
##       orphan warn. Alias sort only among graph hooks.
## @note Script: `${BUILDMASTER_SCRIPTS_HOOK_DIR}/<alias>__graph.cmake`.
## @note The callback must not call `create_*` or graph mutators.
function(buildmaster_on_graph_finalized _function _alias)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_on_graph_finalized")
	cmake_parse_arguments(ARG "" "" "CAPTURE" ${ARGN})
	if(ARG_UNPARSED_ARGUMENTS)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_graph_finalized: unexpected arguments (${ARG_UNPARSED_ARGUMENTS})")
	endif()
	if("${_function}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_graph_finalized: empty function name")
	endif()
	if("${_alias}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_graph_finalized: empty alias")
	endif()
	if(NOT COMMAND "${_function}")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_graph_finalized: function '${_function}' does not exist yet")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_on_graph_finalized: called after finalize")
	endif()

	_buildmaster_hook_write(
		"BUILDMASTER_ON_GRAPH_FINALIZED"
		"graph"
		"${_alias}"
		"${_function}"
		""
		"${ARG_CAPTURE}")
	_buildmaster_component_defer_arm()
	_bm_log_message(COMPONENT DEBUG
		"on_graph_finalized alias=${_alias} → ${_function}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_on_graph_finalized")
endfunction()

## @brief Include per-id hook scripts (alias order) and mark the id done.
## @param[in] _component Component id that just finished cmake/meson materialize.
## @note Sets `BUILDMASTER_ON_MATERIALIZE_<id>_DONE` so finalize can detect
##       hooks whose id was never materialized.
function(_buildmaster_run_component_materialize_hooks _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_run_component_materialize_hooks")
	_buildmaster_hook_run_sorted("BUILDMASTER_ON_MATERIALIZE_${_component}")
	set_property(GLOBAL PROPERTY BUILDMASTER_ON_MATERIALIZE_${_component}_DONE TRUE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_run_component_materialize_hooks")
endfunction()
