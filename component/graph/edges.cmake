# =============================================================================
# component/graph/edges.cmake — depend / link
# =============================================================================

## @brief Whether `(source, dest)` is already stored in two parallel GLOBAL lists.
## @param[in]  _srcs_prop Property name of sources.
## @param[in]  _dsts_prop Property name of dests (same length, same order).
## @param[in]  source     Left side of the pair.
## @param[in]  dest       Right side of the pair.
## @param[out] out_var    Parent-scope TRUE if the pair exists.
function(_bm_graph_pair_in_lists _srcs_prop _dsts_prop source dest out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_pair_in_lists")
	get_property(_srcs GLOBAL PROPERTY ${_srcs_prop})
	get_property(_dsts GLOBAL PROPERTY ${_dsts_prop})
	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(_src STREQUAL "${source}" AND _dst STREQUAL "${dest}")
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_pair_in_lists")
			return()
		endif()
	endforeach()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_pair_in_lists")
endfunction()

## @brief Record an order-only edge if the pair is new. No user WARNING.
## @param[in] source Component id or CMake target (resolved at finalize).
## @param[in] dest   Component id, meta, stage, or existing target.
## @note Called from `buildmaster_link` (auto-dep) and from public
##       `buildmaster_depend` after the duplicate check. A second
##       internal record of the same pair is a silent no-op.
function(_bm_graph_record_dep source dest)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_record_dep")
	_bm_graph_pair_in_lists(
		BUILDMASTER_COMPONENT_DEP_SOURCES
		BUILDMASTER_COMPONENT_DEP_DESTS
		"${source}" "${dest}" _have)
	if(_have)
		_bm_log_message(COMPONENT DEBUG
			"record_dependency ${source} → ${dest} (already present)")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_record_dep")
		return()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS
		"${dest}")
	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "record_dependency ${source} → ${dest}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_record_dep")
endfunction()

## @brief Declare an order-only edge (no link line).
## @param[in] source Component id or CMake target (resolved at finalize).
## @param[in] dest   Component id (→ `<dest>_install`), meta id, existing target,
##            or `<id>_install` / `<id>_configure` / `<id>_build`.
## @note A group id is FATAL on either side (outline only).
## @note A non-BUILDONLY component must not depend on a BUILDONLY component
##       unless the dest is `PRIVATE_HEADERS` (checked at materialize).
##       BUILDONLY may depend on BUILDONLY or normal.
## @note May be called before either endpoint exists; edges are recorded and
##       resolved in `_bm_materialize_finalize`.
## @note A second explicit call with the same `(source, dest)` is WARNING and
##       a no-op (including when `buildmaster_link` already recorded the pair).
##       Unresolvable dest at finalize stays FATAL.
function(buildmaster_depend source dest)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_depend")
	if(ARGC GREATER 2)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_depend: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_depend: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_depend: called after finalize")
	endif()
	if(COMMAND _bm_group_forbid)
		_bm_group_forbid("${source}" "buildmaster_depend")
		_bm_group_forbid("${dest}" "buildmaster_depend")
	endif()
	_bm_graph_pair_in_lists(
		BUILDMASTER_COMPONENT_DEP_SOURCES
		BUILDMASTER_COMPONENT_DEP_DESTS
		"${source}" "${dest}" _have)
	if(_have)
		_bm_log_message(COMPONENT WARNING
			"buildmaster_depend('${source}', '${dest}'): edge already recorded — extra call ignored")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_depend")
		return()
	endif()
	_bm_graph_record_dep("${source}" "${dest}")
	_bm_log_message(COMPONENT DEBUG "buildmaster_depend ${source} → ${dest}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_depend")
endfunction()

## @brief Declare a link from a component (and order when dest is a graph node).
## @param[in] source Registered component id (INTERFACE from `_bm_graph_create`).
## @param[in] dest   Registered component or meta, existing CMake target,
##            an on-disk archive path, or a library spec
##            (`<name>` or `<subdir>/<name>`) under the BM prefix.
## @note A group id is FATAL on either side (outline only).
## @note Dest that is none of the above is FATAL at materialize. Raw system
##       linker names (`shlwapi`, `ws2_32`) belong in `LINK=` / `LINK={…}`
##       on the producer, not here.
## @note A spec dest is resolved with the source component’s mode against
##       `BUILDMASTER_INSTALL_LIBDIR`. The archive need not exist yet.
## @note Linking to a BUILDONLY component is FATAL at materialize unless
##       that dest is `PRIVATE_HEADERS`.
## @note buildmaster_link only participates in the BuildMaster graph; host app
##       targets use target_link_libraries(… PRIVATE <component_id>).
## @note Always records an order-only edge via `_bm_graph_record_dep`
##       so `buildmaster_link(A B)` before `buildmaster_component(B)` still
##       defers A. A second explicit `buildmaster_link` with the same pair
##       is WARNING and a no-op. The auto-dependency does not WARN.
function(buildmaster_link source dest)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_link")
	if(ARGC GREATER 2)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_link: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_link: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_link: called after finalize")
	endif()
	if(COMMAND _bm_group_forbid)
		_bm_group_forbid("${source}" "buildmaster_link")
		_bm_group_forbid("${dest}" "buildmaster_link")
	endif()
	_bm_graph_pair_in_lists(
		BUILDMASTER_COMPONENT_LINK_SOURCES
		BUILDMASTER_COMPONENT_LINK_DESTS
		"${source}" "${dest}" _have)
	if(_have)
		_bm_log_message(COMPONENT WARNING
			"buildmaster_link('${source}', '${dest}'): edge already recorded — extra call ignored")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_link")
		return()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS
		"${dest}")

	_bm_graph_record_dep("${source}" "${dest}")

	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "buildmaster_link ${source} → ${dest}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_link")
endfunction()
