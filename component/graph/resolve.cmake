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

## @brief Whether a registered component is NOINSTALL.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if the NOINSTALL flag is set, else FALSE.
## @note Unregistered ids yield FALSE (property unset).
function(_bm_graph_is_noinstall id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_is_noinstall")
	get_property(_ni GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_NOINSTALL)
	if(_ni)
		set(${out_var} TRUE PARENT_SCOPE)
	else()
		set(${out_var} FALSE PARENT_SCOPE)
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_is_noinstall")
endfunction()

## @brief Whether this component must use build-time configure.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if configure is a build step.
## @note Deferred only when an outgoing DEP dest is a **registered**
##       component or created meta **in this process**.
## @note `buildmaster_link` also records DEP. A dest that only lives
##       inside the nested src (`buildmaster_link(Buffer Logger)` while
##       Logger is not a node here) must **not** defer: the child writes
##       `links/Logger.cmake` during this configure, and flatten needs
##       that file before generate. Deferring here was the Crypto hole
##       (`Setting up Buffer for build-time configure` → empty glob).
function(_bm_graph_has_deferred_configure id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_has_deferred_configure")
	set(_def FALSE)
	set(_why "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	set(_i 0)
	foreach(_s IN LISTS _srcs)
		list(GET _dsts ${_i} _d)
		math(EXPR _i "${_i} + 1")
		if(NOT _s STREQUAL "${id}")
			continue()
		endif()
		_bm_graph_is_registered("${_d}" _is_c)
		if(_is_c)
			set(_def TRUE)
			set(_why "${_d}")
			break()
		endif()
		_bm_meta_is("${_d}" _is_m)
		if(_is_m)
			set(_def TRUE)
			set(_why "${_d}")
			break()
		endif()
	endforeach()
	if(_def)
		_bm_log_message(COMPONENT DEBUG
			"deferred configure ${id} (wait for registered dest '${_why}')")
	endif()
	set(${out_var} "${_def}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_has_deferred_configure")
endfunction()

## @brief Resolve one dependency dest to a CMake target name.
## @param[in]  dest    Component id, meta id, stage name, or existing target.
## @param[out] out_tgt Resolved target (e.g. `<id>_install` or `<id>_build`).
## @param[out] out_ok  TRUE if dest resolved.
## @note Resolution order: registered component → meta → `*_install` /
##       `*_configure` / `*_build` → existing CMake target.
##       A `NOINSTALL` component or meta resolves to `<id>_build`.
function(_bm_graph_resolve_dest dest out_tgt out_ok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_resolve_dest")
	_bm_graph_is_registered("${dest}" _is_comp)
	if(_is_comp)
		_bm_graph_is_noinstall("${dest}" _ni)
		if(_ni)
			set(${out_tgt} "${dest}_build" PARENT_SCOPE)
		else()
			set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		endif()
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	_bm_meta_is("${dest}" _is_meta)
	if(_is_meta)
		get_property(_mni GLOBAL PROPERTY BUILDMASTER_META_${dest}_NOINSTALL)
		if(_mni)
			set(${out_tgt} "${dest}_build" PARENT_SCOPE)
		else()
			set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		endif()
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
## @note FATAL if a publishing `id` depends on a `NOINSTALL` dest that is
##       not `PRIVATE_HEADERS`, unless `id` itself has REPACK (first-level
##       NOINSTALL static members are merged into this id's prefix archive).
function(_bm_graph_dep_targets id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_dep_targets")
	set(_dep_targets "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	_bm_graph_is_noinstall("${id}" _src_ni)
	get_property(_src_repack GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_REPACK)

	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(NOT _src STREQUAL "${id}")
			continue()
		endif()

		_bm_graph_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			_bm_graph_is_noinstall("${_dst}" _dst_ni)
			get_property(_dst_priv GLOBAL PROPERTY
				BUILDMASTER_COMPONENT_${_dst}_PRIVATE_HEADERS)
			if(_dst_ni AND NOT _src_ni AND NOT _dst_priv AND NOT _src_repack)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_depend('${id}', '${_dst}'): a publishing component cannot depend on NOINSTALL '${_dst}' (put REPACK on '${id}', or put NOINSTALL on '${id}' too)")
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
				"buildmaster_depend('${id}', '${_dst}'): cannot resolve dest. Accepted: registered component id → <id>_install or <id>_build; meta id → <id>_install or <id>_build; <id>_install / _configure / _build; existing CMake target.")
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
