# =============================================================================
# component/meta/materialize.cmake — leaves + stage anchors
# =============================================================================

## @brief DFS: expand meta membership to real component leaves; FATAL on cycles.
## @param[in]  id       Meta id to expand.
## @param[in]  stack    Semicolon list of ancestors (cycle path).
## @param[out] out_var  Parent-scope list of component ids (declaration order).
function(_bm_meta_collect_leaves id stack out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_meta_collect_leaves")
	_bm_meta_is("${id}" _is_meta)
	if(NOT _is_meta)
		set(${out_var} "${id}" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_collect_leaves")
		return()
	endif()

	if(stack)
		list(FIND stack "${id}" _hit)
		if(NOT _hit EQUAL -1)
			string(REPLACE ";" " → " _path "${stack}")
			_bm_log_message(COMPONENT FATAL "meta cycle: ${_path} → ${id}")
		endif()
	endif()
	list(APPEND stack "${id}")

	get_property(_members GLOBAL PROPERTY BUILDMASTER_META_${id}_MEMBERS)
	set(_leaves "")
	foreach(_m IN LISTS _members)
		if("${_m}" STREQUAL "")
			continue()
		endif()
		_bm_meta_is("${_m}" _m_meta)
		if(_m_meta)
			_bm_meta_collect_leaves("${_m}" "${stack}" _sub)
			foreach(_s IN LISTS _sub)
				list(APPEND _leaves "${_s}")
			endforeach()
		else()
			list(APPEND _leaves "${_m}")
		endif()
	endforeach()
	if(_leaves)
		list(REMOVE_DUPLICATES _leaves)
	endif()
	set(${out_var} "${_leaves}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_collect_leaves")
endfunction()

## @brief Materialize meta stage anchors; create INTERFACE only if missing.
## @note Runs at the start of finalize, before component materialize, so
##       `buildmaster_link` / `buildmaster_depend` can resolve meta ids.
## @note DFS via `_bm_meta_collect_leaves` (cycles FATAL). Each leaf must
##       be a registered component. `NOINSTALL` leaves are FATAL unless
##       this meta has `REPACK` (merge reads those archives from BUILDDIR).
## @note `buildmaster_meta` already created `<id>` INTERFACE. This
##       function does `add_library(INTERFACE)` only for lazy metas.
##       Always creates empty `<id>_install` / `_build` / `_configure`
##       if missing.
## @note Meta `LINK=` is applied as INTERFACE `target_link_libraries`.
##       Meta `LINKFLAGS` is never applied here (cleared at registration).
function(_bm_meta_materialize)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_meta_materialize")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(NOT _metas)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_materialize")
		return()
	endif()

	foreach(_id IN LISTS _metas)
		_bm_meta_collect_leaves("${_id}" "" _leaves)
		set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES "${_leaves}")
		get_property(_repack GLOBAL PROPERTY BUILDMASTER_META_${_id}_REPACK)

		foreach(_leaf IN LISTS _leaves)
			_bm_graph_is_registered("${_leaf}" _is_comp)
			if(NOT _is_comp)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_meta_add('${_id}', '${_leaf}'): cannot resolve member. Accepted: registered component id or another meta id.")
			endif()
			_bm_graph_is_noinstall("${_leaf}" _ni)
			get_property(_lmode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_MODE)
			if(_ni AND NOT _repack)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_meta_add('${_id}', '${_leaf}'): NOINSTALL components cannot be meta members unless the meta has REPACK")
			endif()
			if(_ni AND _repack AND _lmode STREQUAL "shared")
				_bm_log_message(COMPONENT FATAL
					"buildmaster_meta_add('${_id}', '${_leaf}'): REPACK cannot take a NOINSTALL shared component (the .so/.dll is not installed and its build directory is not a public path)")
			endif()
		endforeach()

		if(NOT TARGET "${_id}")
			add_library(${_id} INTERFACE)
		endif()
		get_property(_meta_link GLOBAL PROPERTY BUILDMASTER_META_${_id}_LINK)
		if(_meta_link)
			target_link_libraries(${_id} INTERFACE ${_meta_link})
			_bm_log_message(COMPONENT DEBUG "${_id}: LINK (raw) → ${_meta_link}")
		endif()
		if(NOT TARGET "${_id}_install")
			add_custom_target(${_id}_install)
		endif()
		if(NOT TARGET "${_id}_build")
			add_custom_target(${_id}_build)
			add_dependencies(${_id}_build ${_id}_install)
		endif()
		if(NOT TARGET "${_id}_configure")
			add_custom_target(${_id}_configure)
			add_dependencies(${_id}_build ${_id}_configure)
		endif()
	endforeach()
	_bm_log_message(COMPONENT DEBUG "Materialized metas: ${_metas}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_materialize")
endfunction()
