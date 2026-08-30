# =============================================================================
# component/toolchain_inherit.cmake — meta TOOLCHAIN inheritance
# =============================================================================
# A meta with TOOLCHAIN=<profile> pushes that profile onto:
#   - expanded leaves (real components)
#   - nested metas (members that are metas)
#   - buildmaster_depend / buildmaster_link dests whose source is the meta
#
# A destination that already has TOOLCHAIN set by the user (create_* options
# or buildmaster_meta) is left unchanged — that is the documented
# exception, not an error.
#
# FATAL only when two metas both inherit onto the same empty destination
# with different profiles (TOOLCHAIN_FROM already names a meta).
#
# Runs after _bm_meta_materialize (leaves known) and before
# cmake/meson materialize so create_*_stages reads the updated OPTSTR.

## @brief TOOLCHAIN value stored on a registered component (from OPTSTR).
## @param[in]  id     Component id.
## @param[out] out_tc Parent-scope profile (empty if unset).
function(_bm_tc_stored id out_tc)
	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	_bm_opt_parse(_i _tc _r _b _w _sr "${_optstr}")
	set(${out_tc} "${_tc}" PARENT_SCOPE)
endfunction()

## @brief Apply profile @p tc to component @p id if it has none.
## @param[in] id          Registered component id.
## @param[in] tc          Profile name from the meta.
## @param[in] source_meta Meta id applying the profile (errors / DEBUG).
## @note Explicit TOOLCHAIN on the component is kept. A second meta that
##       would assign a different inherited profile is FATAL.
function(_bm_tc_inherit_comp id tc source_meta)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_tc_inherit_comp")
	_bm_tc_stored("${id}" _have)
	if(NOT "${_have}" STREQUAL "")
		if("${_have}" STREQUAL "${tc}")
			_bm_log_message(COMPONENT LOWLEVEL
				"Exiting _bm_tc_inherit_comp")
			return()
		endif()
		get_property(_from GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${id}_TOOLCHAIN_FROM)
		if("${_from}" STREQUAL "")
			_bm_log_message(COMPONENT DEBUG
				"meta '${source_meta}' TOOLCHAIN=${tc} skipped for '${id}' (explicit TOOLCHAIN=${_have})")
			_bm_log_message(COMPONENT LOWLEVEL
				"Exiting _bm_tc_inherit_comp")
			return()
		endif()
		_bm_log_message(COMPONENT FATAL
			"TOOLCHAIN conflict on '${id}': already '${_have}' (${_from}), meta '${source_meta}' wants '${tc}'")
	endif()

	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	if("${_optstr}" STREQUAL "")
		set(_optstr "TOOLCHAIN=${tc}")
	else()
		set(_optstr "${_optstr};TOOLCHAIN=${tc}")
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR "${_optstr}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_TOOLCHAIN_FROM
		"meta '${source_meta}'")
	_bm_log_message(COMPONENT DEBUG
		"meta '${source_meta}' TOOLCHAIN=${tc} → component '${id}'")
	_bm_log_message(COMPONENT LOWLEVEL
		"Exiting _bm_tc_inherit_comp")
endfunction()

## @brief Apply profile @p tc to meta @p id if it has none.
## @param[in] id          Meta id.
## @param[in] tc          Profile name.
## @param[in] source_meta Meta applying the profile.
## @note Explicit TOOLCHAIN on the nested meta is kept. Two parent metas
##       inheriting different profiles onto the same empty nested meta is FATAL.
function(_bm_tc_inherit_meta id tc source_meta)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_tc_inherit_meta")
	get_property(_have GLOBAL PROPERTY BUILDMASTER_META_${id}_TOOLCHAIN)
	if(NOT "${_have}" STREQUAL "")
		if("${_have}" STREQUAL "${tc}")
			_bm_log_message(COMPONENT LOWLEVEL
				"Exiting _bm_tc_inherit_meta")
			return()
		endif()
		get_property(_from GLOBAL PROPERTY BUILDMASTER_META_${id}_TOOLCHAIN_FROM)
		if("${_from}" STREQUAL "")
			_bm_log_message(COMPONENT DEBUG
				"meta '${source_meta}' TOOLCHAIN=${tc} skipped for meta '${id}' (explicit TOOLCHAIN=${_have})")
			_bm_log_message(COMPONENT LOWLEVEL
				"Exiting _bm_tc_inherit_meta")
			return()
		endif()
		_bm_log_message(COMPONENT FATAL
			"TOOLCHAIN conflict on meta '${id}': already '${_have}' (${_from}), meta '${source_meta}' wants '${tc}'")
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_TOOLCHAIN "${tc}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_TOOLCHAIN_FROM
		"meta '${source_meta}'")
	_bm_log_message(COMPONENT DEBUG
		"meta '${source_meta}' TOOLCHAIN=${tc} → meta '${id}'")
	_bm_log_message(COMPONENT LOWLEVEL
		"Exiting _bm_tc_inherit_meta")
endfunction()

## @brief Apply @p tc to @p dest if dest is a component or meta.
## @param[in] dest        Token from membership or a graph edge.
## @param[in] tc          Profile name.
## @param[in] source_meta Meta applying the profile.
## @note Custom / host targets that are not a BM component or meta are ignored.
function(_bm_tc_inherit_dest dest tc source_meta)
	if("${dest}" STREQUAL "" OR "${tc}" STREQUAL "")
		return()
	endif()
	_bm_meta_is("${dest}" _is_meta)
	if(_is_meta)
		_bm_tc_inherit_meta("${dest}" "${tc}" "${source_meta}")
		return()
	endif()
	_bm_graph_is_registered("${dest}" _is_comp)
	if(_is_comp)
		_bm_tc_inherit_comp("${dest}" "${tc}" "${source_meta}")
	endif()
endfunction()

## @brief One pass: every meta with TOOLCHAIN pushes it to leaves / members / edges.
## @param[out] out_changed Parent-scope TRUE if any OPTSTR/meta TOOLCHAIN changed.
function(_bm_tc_propagate_pass out_changed)
	set(_changed FALSE)
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	get_property(_dsrc GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_ddst GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	get_property(_lsrc GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldst GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)

	foreach(_id IN LISTS _metas)
		get_property(_tc GLOBAL PROPERTY BUILDMASTER_META_${_id}_TOOLCHAIN)
		if("${_tc}" STREQUAL "")
			continue()
		endif()

		get_property(_leaves GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES)
		foreach(_leaf IN LISTS _leaves)
			_bm_tc_stored("${_leaf}" _before)
			_bm_tc_inherit_dest("${_leaf}" "${_tc}" "${_id}")
			_bm_tc_stored("${_leaf}" _after)
			if(NOT "${_before}" STREQUAL "${_after}")
				set(_changed TRUE)
			endif()
		endforeach()

		get_property(_members GLOBAL PROPERTY BUILDMASTER_META_${_id}_MEMBERS)
		foreach(_m IN LISTS _members)
			get_property(_before GLOBAL PROPERTY BUILDMASTER_META_${_m}_TOOLCHAIN)
			_bm_tc_inherit_dest("${_m}" "${_tc}" "${_id}")
			get_property(_after GLOBAL PROPERTY BUILDMASTER_META_${_m}_TOOLCHAIN)
			if(NOT "${_before}" STREQUAL "${_after}")
				set(_changed TRUE)
			endif()
		endforeach()

		set(_n 0)
		if(_dsrc)
			list(LENGTH _dsrc _n)
		endif()
		set(_i 0)
		while(_i LESS _n)
			list(GET _dsrc ${_i} _src)
			list(GET _ddst ${_i} _dst)
			math(EXPR _i "${_i} + 1")
			if(NOT "${_src}" STREQUAL "${_id}")
				continue()
			endif()
			_bm_tc_inherit_dest("${_dst}" "${_tc}" "${_id}")
		endwhile()

		set(_n 0)
		if(_lsrc)
			list(LENGTH _lsrc _n)
		endif()
		set(_i 0)
		while(_i LESS _n)
			list(GET _lsrc ${_i} _src)
			list(GET _ldst ${_i} _dst)
			math(EXPR _i "${_i} + 1")
			if(NOT "${_src}" STREQUAL "${_id}")
				continue()
			endif()
			_bm_tc_inherit_dest("${_dst}" "${_tc}" "${_id}")
		endwhile()
	endforeach()

	set(${out_changed} "${_changed}" PARENT_SCOPE)
endfunction()

## @brief Repeat inheritance until nested metas stabilize.
## @note FATAL after 64 passes (should be impossible: meta cycles already die
##       in `_bm_meta_collect_leaves`).
function(_bm_tc_propagate_metas)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_tc_propagate_metas")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(NOT _metas)
		_bm_log_message(COMPONENT LOWLEVEL
			"Exiting _bm_tc_propagate_metas")
		return()
	endif()

	set(_guard 0)
	set(_changed TRUE)
	while(_changed)
		math(EXPR _guard "${_guard} + 1")
		if(_guard GREATER 64)
			_bm_log_message(COMPONENT FATAL
				"TOOLCHAIN inherit: exceeded 64 passes")
		endif()
		_bm_tc_propagate_pass(_changed)
	endwhile()

	_bm_log_message(COMPONENT LOWLEVEL
		"Exiting _bm_tc_propagate_metas")
endfunction()
