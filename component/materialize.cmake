# =============================================================================
# component/materialize.cmake — deferred finalize
# =============================================================================
# Children: fragment emit, PRIVATE -I inject + LINKFLAGS fold + apply_links,
#           headers-none.
# Scheduled by _bm_graph_defer_arm (graph.cmake).

include("${CMAKE_CURRENT_LIST_DIR}/materialize/helpers.cmake")

## @brief Deferred materialize: metas, toolchain inherit, components, REPACK,
##        links, orphan warn, hooks.
## @note Idempotent. Scheduled by `_bm_graph_defer_arm`; not public.
##       Harness may call this before configure-time contract checks.
##       Concrete and `buildmaster_meta` INTERFACE stubs already exist. This
##       pass emits stages, fragments, headers-none stamps, REPACK merge
##       targets, meta stage anchors, member wiring and recorded
##       `buildmaster_link` edges.
## @note Order: flush queued git reset/patch → FILES download/unpack →
##       resolve pending SOURCE backends → inject PRIVATE headers
##       `-I` into linker OPTIONS → fold LINKFLAGS into the owner's nested
##       OPTIONS → materialize metas → propagate meta TOOLCHAIN → per-id
##       cmake / meson / none materialize → REPACK → meta wire → apply
##       links → orphan warning → fail if a per-id hook was registered for
##       an id that never materialized → graph hooks (alias order).
## @note Git flush is first so eager nested configure sees patched sources.
## @note FILES runs next so SOURCE trees exist before autodetect / configure.
## @note PRIVATE `-I` injection is before any nested configure so several
##       `buildmaster_link` edges to headers trees each add their own token.
## @note LINKFLAGS fold is next so the owner's nested cmake / meson sees
##       `-DCMAKE_*_LINKER_FLAGS` / `-Dc_link_args` before stages run.
##       Flags stay on that id; they do not walk the graph and do not become
##       INTERFACE on the imported artefact.
## @note `SYSTEM=none` is headers without a backend (`_bm_materialize_none`).
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

	_bm_materialize_inject_private_headers()
	_bm_materialize_inject_linkflags()

	_bm_meta_materialize()
	_bm_tc_propagate_metas()

	if(_ids)
		foreach(_id IN LISTS _ids)
			get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
			if(_sys STREQUAL "cmake")
				_bm_backend_cmake_materialize("${_id}")
			elseif(_sys STREQUAL "meson")
				_bm_backend_meson_materialize("${_id}")
			elseif(_sys STREQUAL "none")
				_bm_materialize_none("${_id}")
			else()
				_bm_log_message(COMPONENT FATAL
					"finalize: unknown system '${_sys}' for '${_id}'")
			endif()
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
