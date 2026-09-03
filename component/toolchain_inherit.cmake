# =============================================================================
# component/toolchain_inherit.cmake — meta TOOLCHAIN / IPO inheritance
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
# A meta with IPO=<mode> (`on` / `off` / `fat`; never `inherit` on the
# meta property) pushes that mode onto the same destinations. A destination
# that already has IPO= — explicit on its optstr, or already stamped by
# an earlier meta — is left unchanged. There is no IPO conflict FATAL:
# the first stamp wins and later metas skip.
#
# Runs after _bm_meta_materialize (leaves known) and before
# cmake/meson materialize so create_*_stages reads the updated OPTSTR.
# Declared TOOLCHAIN= profiles are demanded here so configure does not
# load gcc+clang+lld on a parent-only job.

## @brief TOOLCHAIN value stored on a registered component (from OPTSTR).
## @param[in]  id     Component id.
## @param[out] out_tc Parent-scope profile (empty if unset).
function(_bm_tc_stored id out_tc)
	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	_bm_opt_parse(_i _tc _r _b _w _sr "${_optstr}")
	set(${out_tc} "${_tc}" PARENT_SCOPE)
endfunction()

## @brief IPO mode stored on a registered component (from OPTSTR).
## @param[in]  id       Component id.
## @param[out] out_mode Parent-scope mode from `_bm_opt_parse_ipo`.
##            `inherit` when the key is absent (translator uses parent IPO).
##            `on` / `off` / `fat` when the key is present (explicit or
##            already stamped by a meta into OPTSTR).
function(_bm_ipo_stored id out_mode)
	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	_bm_opt_parse_ipo("${_optstr}" _mode)
	set(${out_mode} "${_mode}" PARENT_SCOPE)
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

## @brief Apply IPO mode @p mode to component @p id if it has none.
## @param[in] id          Registered component id.
## @param[in] mode        `on`, `off` or `fat` from the meta (never `inherit`).
## @param[in] source_meta Meta id applying the mode (DEBUG).
## @note Explicit `IPO=` on the component optstr is kept. An IPO already
##       stamped by an earlier meta is kept. Unlike TOOLCHAIN, a second
##       meta that wants a different mode is not FATAL — it skips.
function(_bm_ipo_inherit_comp id mode source_meta)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_ipo_inherit_comp")
	_bm_ipo_stored("${id}" _have)
	if(NOT "${_have}" STREQUAL "inherit")
		_bm_log_message(COMPONENT DEBUG
			"meta '${source_meta}' IPO=${mode} skipped for '${id}' (already IPO=${_have})")
		_bm_log_message(COMPONENT LOWLEVEL
			"Exiting _bm_ipo_inherit_comp")
		return()
	endif()

	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	if("${_optstr}" STREQUAL "")
		set(_optstr "IPO=${mode}")
	else()
		set(_optstr "${_optstr};IPO=${mode}")
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR "${_optstr}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_IPO_FROM
		"meta '${source_meta}'")
	_bm_log_message(COMPONENT DEBUG
		"meta '${source_meta}' IPO=${mode} → component '${id}'")
	_bm_log_message(COMPONENT LOWLEVEL
		"Exiting _bm_ipo_inherit_comp")
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

## @brief Apply IPO mode @p mode to meta @p id if it has none.
## @param[in] id          Nested meta id.
## @param[in] mode        `on`, `off` or `fat`.
## @param[in] source_meta Meta applying the mode.
## @note Explicit IPO on the nested meta is kept. An IPO already stamped
##       by an earlier parent meta is kept. No FATAL if another parent
##       wants a different mode.
function(_bm_ipo_inherit_meta id mode source_meta)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_ipo_inherit_meta")
	get_property(_have GLOBAL PROPERTY BUILDMASTER_META_${id}_IPO)
	if(NOT "${_have}" STREQUAL "" AND NOT "${_have}" STREQUAL "inherit")
		_bm_log_message(COMPONENT DEBUG
			"meta '${source_meta}' IPO=${mode} skipped for meta '${id}' (already IPO=${_have})")
		_bm_log_message(COMPONENT LOWLEVEL
			"Exiting _bm_ipo_inherit_meta")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_IPO "${mode}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_IPO_FROM
		"meta '${source_meta}'")
	_bm_log_message(COMPONENT DEBUG
		"meta '${source_meta}' IPO=${mode} → meta '${id}'")
	_bm_log_message(COMPONENT LOWLEVEL
		"Exiting _bm_ipo_inherit_meta")
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

## @brief Apply IPO @p mode to @p dest if dest is a component or meta.
## @param[in] dest        Token from membership or a graph edge.
## @param[in] mode        `on`, `off` or `fat`. `inherit` / empty is a no-op.
## @param[in] source_meta Meta applying the mode.
## @note Custom / host targets that are not a BM component or meta are ignored.
function(_bm_ipo_inherit_dest dest mode source_meta)
	if("${dest}" STREQUAL "" OR "${mode}" STREQUAL "" OR "${mode}" STREQUAL "inherit")
		return()
	endif()
	_bm_meta_is("${dest}" _is_meta)
	if(_is_meta)
		_bm_ipo_inherit_meta("${dest}" "${mode}" "${source_meta}")
		return()
	endif()
	_bm_graph_is_registered("${dest}" _is_comp)
	if(_is_comp)
		_bm_ipo_inherit_comp("${dest}" "${mode}" "${source_meta}")
	endif()
endfunction()

## @brief One pass: every meta with TOOLCHAIN or IPO pushes it to
##        leaves / members / edges.
## @param[out] out_changed Parent-scope TRUE if any OPTSTR / meta
##            TOOLCHAIN / IPO property changed.
function(_bm_tc_propagate_pass out_changed)
	set(_changed FALSE)
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	get_property(_dsrc GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_ddst GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	get_property(_lsrc GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldst GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)

	foreach(_id IN LISTS _metas)
		get_property(_tc GLOBAL PROPERTY BUILDMASTER_META_${_id}_TOOLCHAIN)
		get_property(_ipo GLOBAL PROPERTY BUILDMASTER_META_${_id}_IPO)

		get_property(_leaves GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES)
		foreach(_leaf IN LISTS _leaves)
			if(NOT "${_tc}" STREQUAL "")
				_bm_tc_stored("${_leaf}" _before)
				_bm_tc_inherit_dest("${_leaf}" "${_tc}" "${_id}")
				_bm_tc_stored("${_leaf}" _after)
				if(NOT "${_before}" STREQUAL "${_after}")
					set(_changed TRUE)
				endif()
			endif()
			if(NOT "${_ipo}" STREQUAL "" AND NOT "${_ipo}" STREQUAL "inherit")
				_bm_ipo_stored("${_leaf}" _ibefore)
				_bm_ipo_inherit_dest("${_leaf}" "${_ipo}" "${_id}")
				_bm_ipo_stored("${_leaf}" _iafter)
				if(NOT "${_ibefore}" STREQUAL "${_iafter}")
					set(_changed TRUE)
				endif()
			endif()
		endforeach()

		get_property(_members GLOBAL PROPERTY BUILDMASTER_META_${_id}_MEMBERS)
		foreach(_m IN LISTS _members)
			if(NOT "${_tc}" STREQUAL "")
				get_property(_before GLOBAL PROPERTY BUILDMASTER_META_${_m}_TOOLCHAIN)
				_bm_tc_inherit_dest("${_m}" "${_tc}" "${_id}")
				get_property(_after GLOBAL PROPERTY BUILDMASTER_META_${_m}_TOOLCHAIN)
				if(NOT "${_before}" STREQUAL "${_after}")
					set(_changed TRUE)
				endif()
			endif()
			if(NOT "${_ipo}" STREQUAL "" AND NOT "${_ipo}" STREQUAL "inherit")
				get_property(_before GLOBAL PROPERTY BUILDMASTER_META_${_m}_IPO)
				_bm_ipo_inherit_dest("${_m}" "${_ipo}" "${_id}")
				get_property(_after GLOBAL PROPERTY BUILDMASTER_META_${_m}_IPO)
				if(NOT "${_before}" STREQUAL "${_after}")
					set(_changed TRUE)
				endif()
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
			if(NOT "${_tc}" STREQUAL "")
				_bm_tc_inherit_dest("${_dst}" "${_tc}" "${_id}")
			endif()
			if(NOT "${_ipo}" STREQUAL "" AND NOT "${_ipo}" STREQUAL "inherit")
				_bm_ipo_inherit_dest("${_dst}" "${_ipo}" "${_id}")
			endif()
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
			if(NOT "${_tc}" STREQUAL "")
				_bm_tc_inherit_dest("${_dst}" "${_tc}" "${_id}")
			endif()
			if(NOT "${_ipo}" STREQUAL "" AND NOT "${_ipo}" STREQUAL "inherit")
				_bm_ipo_inherit_dest("${_dst}" "${_ipo}" "${_id}")
			endif()
		endwhile()
	endforeach()

	set(${out_changed} "${_changed}" PARENT_SCOPE)
endfunction()

## @brief Demand every profile that a component or meta actually pinned.
## @note Parent profile is already demanded at Meson native init.
##       A leaf that inherited TOOLCHAIN= from a meta is demanded here
##       with who `component:<id>:meta:<mid>`.
function(_bm_tc_demand_declared)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_tc_demand_declared")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	foreach(_id IN LISTS _ids)
		_bm_tc_stored("${_id}" _tc)
		if("${_tc}" STREQUAL "")
			continue()
		endif()
		get_property(_from GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_TOOLCHAIN_FROM)
		set(_who "component:${_id}")
		if(NOT "${_from}" STREQUAL "")
			if(_from MATCHES "meta '([^']+)'")
				set(_who "component:${_id}:meta:${CMAKE_MATCH_1}")
			endif()
		endif()
		_bm_tc_demand_profile("${_tc}" "${_who}")
	endforeach()
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	foreach(_id IN LISTS _metas)
		get_property(_tc GLOBAL PROPERTY BUILDMASTER_META_${_id}_TOOLCHAIN)
		if("${_tc}" STREQUAL "")
			continue()
		endif()
		_bm_tc_demand_profile("${_tc}" "meta:${_id}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_tc_demand_declared")
endfunction()

## @brief Repeat inheritance until nested metas stabilize.
## @note FATAL after 64 passes (should be impossible: meta cycles already die
##       in `_bm_meta_collect_leaves`).
## @note Always demands declared TOOLCHAIN= profiles, even when there
##       are no metas (explicit leaf TOOLCHAIN= still has to resolve).
function(_bm_tc_propagate_metas)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_tc_propagate_metas")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(_metas)
		set(_guard 0)
		set(_changed TRUE)
		while(_changed)
			math(EXPR _guard "${_guard} + 1")
			if(_guard GREATER 64)
				_bm_log_message(COMPONENT FATAL
					"TOOLCHAIN/IPO inherit: exceeded 64 passes")
			endif()
			_bm_tc_propagate_pass(_changed)
		endwhile()
	endif()

	_bm_tc_demand_declared()
	_bm_log_message(COMPONENT LOWLEVEL
		"Exiting _bm_tc_propagate_metas")
endfunction()
