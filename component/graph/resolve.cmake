# =============================================================================
# component/graph/resolve.cmake — registry queries + dest → target
# =============================================================================

## @brief Whether `id` was registered with _bm_graph_create.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE/FALSE.
## @note Meta ids are not included; use `_bm_meta_is()`.
function(_bm_graph_is_registered id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_is_registered")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_is_registered")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_is_registered")
endfunction()

## @brief Whether a registered component is BUILDONLY.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if the BUILDONLY flag is set, else FALSE.
## @note Unregistered ids yield FALSE (property unset).
function(_bm_graph_is_buildonly id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_is_buildonly")
	get_property(_bo GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_BUILDONLY)
	if(_bo)
		set(${out_var} TRUE PARENT_SCOPE)
	else()
		set(${out_var} FALSE PARENT_SCOPE)
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_is_buildonly")
endfunction()

## @brief Whether this component must use build-time configure.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if `id` appears as a dependency source.
## @note Configure-time configure is used when the component has no recorded
##       incoming edges; otherwise configure runs as a build step (deferred
##       template) so artifacts from dest can exist first.
function(_bm_graph_has_deferred_configure id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_has_deferred_configure")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	if(_srcs)
		list(FIND _srcs "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_has_deferred_configure")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_has_deferred_configure")
endfunction()

## @brief Resolve one dependency dest to a CMake target name.
## @param[in]  dest    Component id, meta id, stage name, or existing target.
## @param[out] out_tgt Resolved target (e.g. `<id>_install`).
## @param[out] out_ok  TRUE if dest resolved.
## @note Resolution order: registered component → meta → `*_install` /
##       `*_configure` / `*_build` → existing CMake target.
function(_bm_graph_resolve_dest dest out_tgt out_ok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_resolve_dest")
	_bm_graph_is_registered("${dest}" _is_comp)
	if(_is_comp)
		set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	_bm_meta_is("${dest}" _is_meta)
	if(_is_meta)
		set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	if("${dest}" MATCHES "^(.+)_(install|configure|build)$")
		set(${out_tgt} "${dest}" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	if(TARGET "${dest}")
		set(${out_tgt} "${dest}" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	set(${out_tgt} "" PARENT_SCOPE)
	set(${out_ok} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
endfunction()

## @brief Space-separated wait targets for the deferred fragment.
## @param[in]  id      Component whose outgoing dependency edges are collected.
## @param[out] out_var Parent-scope string of unique target names, space-joined
##            (empty if this component has no recorded dests).
## @note FATAL if dest cannot be resolved, unless the same pair is also a
##       `buildmaster_link` (spec or on-disk archive: link-only, no wait target).
##       FATAL if a non-BUILDONLY `id` depends on a BUILDONLY dest that is
##       not `PRIVATE_HEADERS`.
function(_bm_graph_dep_targets id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_dep_targets")
	set(_dep_targets "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	_bm_graph_is_buildonly("${id}" _src_bo)

	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(NOT _src STREQUAL "${id}")
			continue()
		endif()

		_bm_graph_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			_bm_graph_is_buildonly("${_dst}" _dst_bo)
			get_property(_dst_priv GLOBAL PROPERTY
				BUILDMASTER_COMPONENT_${_dst}_PRIVATE_HEADERS)
			if(_dst_bo AND NOT _src_bo AND NOT _dst_priv)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_depend('${id}', '${_dst}'): a non-BUILDONLY component cannot depend on BUILDONLY '${_dst}' (publish it with a REPACK meta, or make '${id}' BUILDONLY too)")
			endif()
		endif()

		_bm_graph_resolve_dest("${_dst}" _tgt _ok)
		if(NOT _ok)
			_bm_graph_pair_in_lists(
				BUILDMASTER_COMPONENT_LINK_SOURCES
				BUILDMASTER_COMPONENT_LINK_DESTS
				"${id}" "${_dst}" _also_link)
			if(_also_link)
				_bm_log_message(COMPONENT DEBUG
					"buildmaster_depend('${id}', '${_dst}'): dest is link-only (spec or archive), no wait target")
				continue()
			endif()
			_bm_log_message(COMPONENT FATAL
				"buildmaster_depend('${id}', '${_dst}'): cannot resolve dest. Accepted: registered component id → <id>_install; meta id → <id>_install; <id>_install / _configure / _build; existing CMake target.")
		endif()
		list(APPEND _dep_targets "${_tgt}")
	endforeach()
	if(_dep_targets)
		list(REMOVE_DUPLICATES _dep_targets)
	endif()
	string(REPLACE ";" " " _joined "${_dep_targets}")
	set(${out_var} "${_joined}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_dep_targets")
endfunction()
