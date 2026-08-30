# =============================================================================
# component/materialize.cmake — deferred finalize
# =============================================================================
# Children: fragment emit, PRIVATE -I inject + LINKFLAGS fold + apply_links,
#           headers-none.
# Scheduled by _bm_graph_defer_arm (graph.cmake).

include("${CMAKE_CURRENT_LIST_DIR}/materialize/helpers.cmake")

## @brief Materialize one registered component by SYSTEM.
function(_bm_materialize_one id)
	get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_SYSTEM)
	if("${_sys}" STREQUAL "")
		return()
	endif()
	if(_sys STREQUAL "cmake")
		_bm_backend_cmake_materialize("${id}")
	elseif(_sys STREQUAL "meson")
		_bm_backend_meson_materialize("${id}")
	elseif(_sys STREQUAL "none")
		_bm_materialize_none("${id}")
	else()
		_bm_log_message(COMPONENT FATAL
			"finalize: unknown system '${_sys}' for '${id}'")
	endif()
endfunction()

## @brief Deferred materialize: groups plan, metas, toolchain inherit,
##        components, REPACK, links, orphan warn, hooks.
## @note Idempotent. Scheduled by `_bm_graph_defer_arm`; not public.
## @note Group events (`banner:id:depth` / `comp:id`) are played in order so
##       a member configure sits under its group banner.
function(_bm_materialize_finalize)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_finalize")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_finalize")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED TRUE)

	if(COMMAND _bm_git_flush_all)
		_bm_git_flush_all()
	endif()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		foreach(_id IN LISTS _ids)
			_bm_comp_apply_files("${_id}")
			_bm_comp_resolve_pending_files("${_id}")
		endforeach()
	endif()

	if(COMMAND _bm_group_plan)
		_bm_group_plan()
	endif()

	_bm_materialize_inject_private_headers()
	_bm_materialize_inject_linkflags()

	_bm_meta_materialize()
	_bm_tc_propagate_metas()

	get_property(_events GLOBAL PROPERTY BUILDMASTER_GROUP_EVENTS)
	if(_events)
		foreach(_ev IN LISTS _events)
			if(_ev MATCHES "^banner:([^:]+):([0-9]+)$")
				_bm_group_emit_banner("${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}")
			elseif(_ev MATCHES "^comp:(.+)$")
				_bm_materialize_one("${CMAKE_MATCH_1}")
			endif()
		endforeach()
	elseif(_ids)
		foreach(_id IN LISTS _ids)
			_bm_materialize_one("${_id}")
		endforeach()
	endif()

	_bm_repack_materialize()
	_bm_meta_wire()
	_bm_materialize_apply_links()
	_bm_meta_warn_orphans()

	get_property(_hook_ids GLOBAL PROPERTY BUILDMASTER_ON_MATERIALIZE_IDS)
	if(_hook_ids)
		list(REMOVE_DUPLICATES _hook_ids)
		foreach(_hid IN LISTS _hook_ids)
			get_property(_hook_done GLOBAL PROPERTY
				BUILDMASTER_ON_MATERIALIZE_${_hid}_DONE)
			if(NOT _hook_done)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_hook_component('${_hid}'): component was never materialized")
			endif()
		endforeach()
	endif()

	_bm_hook_run_sorted("BUILDMASTER_ON_GRAPH_FINALIZED")

	_bm_log_message(COMPONENT DEBUG "Component graph finalized")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_finalize")
endfunction()
