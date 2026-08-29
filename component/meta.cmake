# =============================================================================
# component/meta.cmake — meta components (INTERFACE collections, no sources)
# =============================================================================
# Public: buildmaster_meta, buildmaster_meta_add
# Materialize runs from _bm_graph_finalize (materialize.cmake)
# BEFORE real components, so buildmaster_link/dependency already see meta ids.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief Ensure `id` exists in the meta registry (lazy create).
## @param[in] id Meta component identifier (non-empty).
## @note Does not create CMake targets. Safe before `buildmaster_meta()`.
## @note First call appends to BUILDMASTER_META_IDS and sets TITLE=id,
##       WHOLE=FALSE, CREATED=FALSE, INDENT=0, TOOLCHAIN="". Later calls
##       are no-ops.
## @note Empty id is FATAL.
function(_bm_meta_ensure id)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_meta_ensure")
	if("${id}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "meta id must be non-empty")
	endif()
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_ensure")
			return()
		endif()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_META_IDS "${id}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_TITLE "${id}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_WHOLE FALSE)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_REPACK FALSE)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_CREATED FALSE)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_INDENT 0)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_TOOLCHAIN "")
	_bm_log_message(COMPONENT DEBUG "Lazy-registered meta ${id}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_ensure")
endfunction()

## @brief Whether `id` is a registered meta (including lazy-only adds).
## @param[in]  id      Identifier to look up in BUILDMASTER_META_IDS.
## @param[out] out_var Parent-scope TRUE if present, else FALSE.
## @note Does not require `buildmaster_meta()`; `buildmaster_meta_add`
##       alone is enough for this to return TRUE.
function(_bm_meta_is id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_meta_is")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_is")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_is")
endfunction()

## @brief Register a meta collection (no sources; membership + INTERFACE).
## @param[in] _id              Identifier (INTERFACE target name after this call).
## @param[in] _title           Human-readable title (STATUS only).
## @param[in] options_string   Optional "KEY=value;…". Keys: INDENT / INDENT_LEVEL,
##            WHOLE (flag), REPACK (flag), TOOLCHAIN (inherited by members
##            without their own), LINK= / LINK={…}, LINKFLAGS= / LINKFLAGS={…}.
## @note `REPACK`: merge every produced *static* archive of the member leaves
##       into one prefix archive named after `_id`. Shared/DLL members are
##       not merged (WARNING); they stay INTERFACE links on the meta.
##       Wait edge per leaf: `_install` if the leaf publishes; `_build` if
##       `BUILDONLY`. `REPACK` on `buildmaster_component` is FATAL.
## @note Creates an empty INTERFACE `<id>` before return so ALIAS /
##       target_* in the same CMakeLists (before DEFER) see the target.
## @note RENAME / BUILDONLY / STRIPRES → INFO, ignored (meta produces no
##       archives of its own except the REPACK merge). STRIPRES default is
##       ON; the INFO fires only when the user actually wrote the key.
## @note `PC` / `PC={…}` is FATAL on a meta.
## @note `GIT={…}` with FETCH / SWITCH / RESET / PATCH is FATAL on a meta
##       (no srcdir). Empty `GIT` / `GIT={}` is the parser WARNING only.
## @note A second `buildmaster_meta()` for the same id is FATAL.
function(buildmaster_meta _id _title)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_meta")
	if(ARGC GREATER 3)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta: too many arguments (expected at most one options string).")
	endif()
	if("${_id}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "buildmaster_meta: empty id")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta('${_id}'): called after finalize")
	endif()

	get_property(_comp_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_comp_ids)
		list(FIND _comp_ids "${_id}" _cidx)
		if(NOT _cidx EQUAL -1)
			_bm_log_message(COMPONENT FATAL
				"buildmaster_meta: '${_id}' is already a component id")
		endif()
	endif()

	_bm_meta_ensure("${_id}")
	get_property(_created GLOBAL PROPERTY BUILDMASTER_META_${_id}_CREATED)
	if(_created)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta: duplicate id '${_id}'")
	endif()

	set(_optstr "")
	if(ARGC GREATER 2)
		set(_optstr "${ARGV2}")
	endif()

	_bm_opt_parse(
		_indent _tc _rename _buildonly _whole _stripres "${_optstr}")
	_bm_opt_parse_pc(
		"${_optstr}" _pc_present _pc_enabled _pc_name _pc_ver _pc_desc)
	_bm_opt_parse_link("${_optstr}" _meta_link)
	_bm_opt_parse_linkflags("${_optstr}" _meta_linkflags)
	_bm_opt_parse_git(
		"${_optstr}" _git_present _git_fetch _git_switch _git_reset
		_git_patches _git_title)
	_bm_opt_parse_repack("${_optstr}" _repack)
	if(_pc_present)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta('${_id}'): PC={…} is not allowed on a meta (unbounded Requires / clash with upstream .pc). Set PC on the concrete member components instead.")
	endif()
	if(_git_present AND (_git_fetch OR NOT "${_git_switch}" STREQUAL "" OR _git_reset OR _git_patches))
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta('${_id}'): cannot run git commands on a sourceless meta component")
	endif()
	if(_buildonly)
		_bm_log_message(COMPONENT INFO
			"buildmaster_meta('${_id}'): BUILDONLY ignored (meta does not install member artifacts)")
	endif()
	if("${_optstr}" MATCHES "[Rr][Ee][Nn][Aa][Mm][Ee]")
		_bm_log_message(COMPONENT INFO
			"buildmaster_meta('${_id}'): RENAME ignored (meta has no produced archives of its own)")
	endif()
	if("${_optstr}" MATCHES "[Ss][Tt][Rr][Ii][Pp][Rr][Ee][Ss]")
		_bm_log_message(COMPONENT INFO
			"buildmaster_meta('${_id}'): STRIPRES ignored (meta has no produced archives of its own)")
	endif()

	set(_disp "${_title}")
	if("${_disp}" STREQUAL "")
		set(_disp "${_id}")
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_TITLE "${_disp}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_CREATED TRUE)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_INDENT "${_indent}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_TOOLCHAIN "${_tc}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_LINK "${_meta_link}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_LINKFLAGS "${_meta_linkflags}")
	if(_whole)
		set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_WHOLE TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_WHOLE FALSE)
	endif()
	if(_repack)
		set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_REPACK TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_REPACK FALSE)
	endif()

	add_library("${_id}" INTERFACE)

	_bm_graph_defer_arm()
	if(_repack)
		_bm_log_message(COMPONENT DEBUG "Registered meta ${_id} REPACK")
	elseif(_meta_link OR _meta_linkflags)
		_bm_log_message(COMPONENT DEBUG
			"Registered meta ${_id} LINK=${_meta_link} LINKFLAGS=${_meta_linkflags}")
	else()
		_bm_log_message(COMPONENT DEBUG "Registered meta ${_id}")
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_meta")
endfunction()

## @brief Declare membership of one or more ids in a meta collection.
## @param[in] meta    Meta id (created lazily if buildmaster_meta was not
##                    called yet).
## @param[in] ARGN    Member ids (components, other metas). Duplicates are
##                    ignored. Order of first addition is flatten order.
## @note Membership is not consumption. Nothing compiles the collection until
##       some consumer buildmaster_link / buildmaster_depend / host
##       target_link_libraries points at the meta.
function(buildmaster_meta_add meta)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_meta_add")
	if("${meta}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "buildmaster_meta_add: empty meta id")
	endif()
	if(ARGC LESS 2)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta_add: need at least one member")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta_add: called after finalize")
	endif()

	get_property(_comp_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_comp_ids)
		list(FIND _comp_ids "${meta}" _cidx)
		if(NOT _cidx EQUAL -1)
			_bm_log_message(COMPONENT FATAL
				"buildmaster_meta_add: '${meta}' is a create_*_component id, not a meta")
		endif()
	endif()

	_bm_meta_ensure("${meta}")

	get_property(_members GLOBAL PROPERTY BUILDMASTER_META_${meta}_MEMBERS)
	foreach(_m IN LISTS ARGV)
		if(_m STREQUAL "${meta}")
			continue()
		endif()
		if(_m STREQUAL "")
			continue()
		endif()
		# ARGV[0] is the meta id
		if(_m STREQUAL "${meta}")
			continue()
		endif()
	endforeach()

	math(EXPR _n "${ARGC} - 1")
	set(_i 1)
	while(_i LESS ARGC)
		list(GET ARGV ${_i} _m)
		math(EXPR _i "${_i} + 1")
		if("${_m}" STREQUAL "")
			continue()
		endif()
		if(_m STREQUAL "${meta}")
			_bm_log_message(COMPONENT FATAL
				"buildmaster_meta_add('${meta}', '${_m}'): a meta cannot contain itself")
		endif()
		if(_members)
			list(FIND _members "${_m}" _idx)
			if(NOT _idx EQUAL -1)
				continue()
			endif()
		endif()
		list(APPEND _members "${_m}")
	endwhile()
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${meta}_MEMBERS "${_members}")

	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "buildmaster_meta_add ${meta} members=${_members}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_meta_add")
endfunction()

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
##       be a registered component. `BUILDONLY` leaves are FATAL unless
##       this meta has `REPACK` (merge reads those archives from BUILDDIR).
## @note `buildmaster_meta` already created `<id>` INTERFACE. This
##       function does `add_library(INTERFACE)` only for lazy metas.
##       Always creates empty `<id>_install` / `_build` / `_configure`
##       if missing.
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
			_bm_comp_is_registered("${_leaf}" _is_comp)
			if(NOT _is_comp)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_meta_add('${_id}', '${_leaf}'): cannot resolve member. Accepted: registered component id or another meta id.")
			endif()
			_bm_comp_is_buildonly("${_leaf}" _bo)
			get_property(_lmode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_MODE)
			if(_bo AND NOT _repack)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_meta_add('${_id}', '${_leaf}'): BUILDONLY components cannot be meta members unless the meta has REPACK")
			endif()
			if(_bo AND _repack AND _lmode STREQUAL "shared")
				_bm_log_message(COMPONENT FATAL
					"buildmaster_meta_add('${_id}', '${_leaf}'): REPACK cannot take a BUILDONLY shared component (the .so/.dll is not installed and its build directory is not a public path)")
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
		get_property(_meta_linkflags GLOBAL PROPERTY BUILDMASTER_META_${_id}_LINKFLAGS)
		if(_meta_linkflags)
			target_link_options(${_id} INTERFACE ${_meta_linkflags})
			_bm_log_message(COMPONENT DEBUG "${_id}: LINKFLAGS (raw) → ${_meta_linkflags}")
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

## @brief After real components exist: wire `<meta>_install` and INTERFACE.
## @note Wait edge: leaf `_install` unless the leaf is BUILDONLY, then
##       `_build` (end of that component's phase).
## @note `REPACK` metas do not INTERFACE-link static leaves (the merge
##       publishes one archive). Shared/headers leaves stay INTERFACE;
##       shared also emits WARNING (cannot fold a .so/.dll into the pack).
## @note Without REPACK, WHOLE flattens static produced files; otherwise
##       `target_link_libraries(<meta> INTERFACE <leaf>)`.
function(_bm_meta_wire)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_meta_wire")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(NOT _metas)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_wire")
		return()
	endif()

	foreach(_id IN LISTS _metas)
		get_property(_leaves GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES)
		get_property(_whole GLOBAL PROPERTY BUILDMASTER_META_${_id}_WHOLE)
		get_property(_repack GLOBAL PROPERTY BUILDMASTER_META_${_id}_REPACK)

		foreach(_leaf IN LISTS _leaves)
			_bm_comp_is_buildonly("${_leaf}" _bo)
			if(_bo)
				if(TARGET "${_leaf}_build")
					add_dependencies(${_id}_install ${_leaf}_build)
				endif()
			else()
				if(TARGET "${_leaf}_install")
					add_dependencies(${_id}_install ${_leaf}_install)
				endif()
			endif()
		endforeach()

		if(_repack)
			foreach(_leaf IN LISTS _leaves)
				get_property(_lmode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_MODE)
				if(_lmode STREQUAL "shared")
					_bm_log_message(COMPONENT WARNING
						"meta '${_id}': REPACK cannot fold shared '${_leaf}' into one archive; the .so/.dll stays a separate INTERFACE link (the pack is not a single shared library)")
					if(TARGET "${_leaf}")
						target_link_libraries(${_id} INTERFACE ${_leaf})
					endif()
				elseif(_lmode STREQUAL "headers")
					if(TARGET "${_leaf}")
						target_link_libraries(${_id} INTERFACE ${_leaf})
					endif()
				endif()
			endforeach()
			continue()
		endif()

		if(_whole)
			set(_paths "")
			set(_emitted "")
			foreach(_leaf IN LISTS _leaves)
				get_property(_lmode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_MODE)
				get_property(_lwhole GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_WHOLE)
				if(_lmode STREQUAL "shared" OR _lmode STREQUAL "headers")
					if(TARGET "${_leaf}")
						target_link_libraries(${_id} INTERFACE ${_leaf})
					endif()
					continue()
				endif()
				if(_lwhole)
					if(TARGET "${_leaf}")
						target_link_libraries(${_id} INTERFACE ${_leaf})
					endif()
					get_property(_files GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_FILES)
					foreach(_f IN LISTS _files)
						list(APPEND _emitted "${_f}")
					endforeach()
					continue()
				endif()
				get_property(_files GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_FILES)
				foreach(_f IN LISTS _files)
					if(_emitted)
						list(FIND _emitted "${_f}" _hit)
						if(NOT _hit EQUAL -1)
							continue()
						endif()
					endif()
					list(APPEND _emitted "${_f}")
					list(APPEND _paths "${_f}")
				endforeach()
			endforeach()
			if(_paths)
				_bm_opt_whole_items(_witems ${_paths})
				target_link_libraries(${_id} INTERFACE ${_witems})
			elseif(_whole)
				set(_any_static FALSE)
				foreach(_leaf IN LISTS _leaves)
					get_property(_lmode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_leaf}_MODE)
					if(_lmode STREQUAL "static")
						set(_any_static TRUE)
					endif()
				endforeach()
				if(NOT _any_static)
					_bm_log_message(COMPONENT INFO
						"meta '${_id}': WHOLE ignored (no static produced archives among members)")
				endif()
			endif()
		else()
			foreach(_leaf IN LISTS _leaves)
				if(TARGET "${_leaf}")
					target_link_libraries(${_id} INTERFACE ${_leaf})
				endif()
			endforeach()
		endif()
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_wire")
endfunction()

## @brief Warn once about registered components/metas with no consumer.
## @note Membership is not consumption for the meta itself, but:
##       - leaves of any meta are not orphans;
##       - a nested meta is consumed if an ancestor meta is consumed;
##       - REPACK meta members are consumed only if that meta id
##         itself is consumed; an unused repack orphans both itself and
##         inputs that nothing else consumes;
##       - host target_link_libraries to a component/meta id counts;
##       - host add_dependencies / custom-target DEPENDS on <id>,
##         <id>_install, <id>_build or <id>_configure counts (smoke,
##         BUILDONLY stages that never enter a link line).
function(_bm_meta_warn_orphans)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_meta_warn_orphans")
	get_property(_comps GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	get_property(_dsrc GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_ddst GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	get_property(_lsrc GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldst GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)

	set(_mentioned "")
	foreach(_x IN LISTS _dsrc _ddst _lsrc _ldst)
		if(NOT "${_x}" STREQUAL "")
			list(APPEND _mentioned "${_x}")
		endif()
	endforeach()

	# Host / INTERFACE links and graph edges in this CMake tree
	set(_dirs "${CMAKE_SOURCE_DIR}")
	set(_seen_dirs "${CMAKE_SOURCE_DIR}")
	while(_dirs)
		list(GET _dirs 0 _dir)
		list(REMOVE_AT _dirs 0)
		get_property(_tgts DIRECTORY "${_dir}" PROPERTY BUILDSYSTEM_TARGETS)
		foreach(_t IN LISTS _tgts)
			if(NOT TARGET "${_t}")
				continue()
			endif()
			get_property(_ll TARGET "${_t}" PROPERTY LINK_LIBRARIES)
			get_property(_il TARGET "${_t}" PROPERTY INTERFACE_LINK_LIBRARIES)
			get_property(_md TARGET "${_t}" PROPERTY MANUALLY_ADDED_DEPENDENCIES)
			foreach(_u IN LISTS _ll _il _md)
				if("${_u}" STREQUAL "")
					continue()
				endif()
				list(APPEND _mentioned "${_u}")
				foreach(_sfx IN ITEMS _install _build _configure)
					string(LENGTH "${_sfx}" _sl)
					string(LENGTH "${_u}" _ul)
					if(_ul GREATER _sl)
						math(EXPR _cut "${_ul} - ${_sl}")
						string(SUBSTRING "${_u}" ${_cut} ${_sl} _end)
						if(_end STREQUAL "${_sfx}")
							string(SUBSTRING "${_u}" 0 ${_cut} _stem)
							list(APPEND _mentioned "${_stem}")
						endif()
					endif()
				endforeach()
			endforeach()
		endforeach()
		get_property(_subs DIRECTORY "${_dir}" PROPERTY SUBDIRECTORIES)
		foreach(_s IN LISTS _subs)
			list(FIND _seen_dirs "${_s}" _hit)
			if(_hit EQUAL -1)
				list(APPEND _seen_dirs "${_s}")
				list(APPEND _dirs "${_s}")
			endif()
		endforeach()
	endwhile()

	if(_mentioned)
		list(REMOVE_DUPLICATES _mentioned)
	endif()

	# Repack inputs count only when the repack id is already consumed.
	get_property(_rep_ids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
	foreach(_rid IN LISTS _rep_ids)
		set(_rep_used FALSE)
		if(_mentioned)
			list(FIND _mentioned "${_rid}" _hit)
			if(NOT _hit EQUAL -1)
				set(_rep_used TRUE)
			endif()
		endif()
		if(_rep_used)
			get_property(_rin GLOBAL PROPERTY BUILDMASTER_REPACK_${_rid}_INPUTS)
			foreach(_in IN LISTS _rin)
				if(NOT "${_in}" STREQUAL "")
					list(APPEND _mentioned "${_in}")
				endif()
			endforeach()
		endif()
	endforeach()
	if(_mentioned)
		list(REMOVE_DUPLICATES _mentioned)
	endif()

	set(_consumed_metas "")
	foreach(_m IN LISTS _metas)
		if(_mentioned)
			list(FIND _mentioned "${_m}" _hit)
			if(NOT _hit EQUAL -1)
				list(APPEND _consumed_metas "${_m}")
			endif()
		endif()
	endforeach()

	set(_changed TRUE)
	while(_changed)
		set(_changed FALSE)
		foreach(_m IN LISTS _consumed_metas)
			get_property(_members GLOBAL PROPERTY BUILDMASTER_META_${_m}_MEMBERS)
			foreach(_mem IN LISTS _members)
				_bm_meta_is("${_mem}" _mem_meta)
				if(NOT _mem_meta)
					continue()
				endif()
				list(FIND _consumed_metas "${_mem}" _hit)
				if(_hit EQUAL -1)
					list(APPEND _consumed_metas "${_mem}")
					set(_changed TRUE)
				endif()
			endforeach()
		endforeach()
	endwhile()
	if(_consumed_metas)
		list(REMOVE_DUPLICATES _consumed_metas)
	endif()

	set(_consumed_comps "")
	foreach(_c IN LISTS _comps)
		if(_mentioned)
			list(FIND _mentioned "${_c}" _hit)
			if(NOT _hit EQUAL -1)
				list(APPEND _consumed_comps "${_c}")
			endif()
		endif()
	endforeach()
	foreach(_m IN LISTS _metas)
		get_property(_leaves GLOBAL PROPERTY BUILDMASTER_META_${_m}_LEAVES)
		foreach(_l IN LISTS _leaves)
			list(APPEND _consumed_comps "${_l}")
		endforeach()
	endforeach()
	if(_consumed_comps)
		list(REMOVE_DUPLICATES _consumed_comps)
	endif()

	set(_orphans "")
	foreach(_c IN LISTS _comps)
		if(_consumed_comps)
			list(FIND _consumed_comps "${_c}" _hit)
			if(NOT _hit EQUAL -1)
				continue()
			endif()
		endif()
		list(APPEND _orphans "${_c}")
	endforeach()
	foreach(_m IN LISTS _metas)
		if(_consumed_metas)
			list(FIND _consumed_metas "${_m}" _hit)
			if(NOT _hit EQUAL -1)
				continue()
			endif()
		endif()
		list(APPEND _orphans "${_m}")
	endforeach()

	if(_orphans)
		list(REMOVE_DUPLICATES _orphans)
		string(REPLACE ";" ", " _list "${_orphans}")
		_bm_log_message(COMPONENT WARNING
			"orphan component(s) / meta(s) (not consumed by buildmaster_link / buildmaster_depend / host link / host DEPENDS / consumed REPACK meta): ${_list}")
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_meta_warn_orphans")
endfunction()
