# =============================================================================
# component/meta.cmake — meta components (INTERFACE collections, no sources)
# =============================================================================
# Public: create_meta_component, meta_component_add
# Materialize runs from _buildmaster_finalize_components (materialize.cmake)
# BEFORE real components, so component_link/dependency already see meta ids.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief Ensure `id` exists in the meta registry (lazy create).
## @param[in] id Meta component identifier (non-empty).
## @note Does not create CMake targets. Safe before `create_meta_component()`.
## @note First call appends to BUILDMASTER_META_IDS and sets TITLE=id,
##       WHOLE=FALSE, CREATED=FALSE, INDENT=0, TOOLCHAIN="". Later calls
##       are no-ops.
## @note Empty id is FATAL.
function(_buildmaster_meta_ensure id)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_meta_ensure")
	if("${id}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL "meta id must be non-empty")
	endif()
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_ensure")
			return()
		endif()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_META_IDS "${id}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_TITLE "${id}")
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_WHOLE FALSE)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_CREATED FALSE)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_INDENT 0)
	set_property(GLOBAL PROPERTY BUILDMASTER_META_${id}_TOOLCHAIN "")
	buildmaster_message(COMPONENT DEBUG "Lazy-registered meta ${id}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_ensure")
endfunction()

## @brief Whether `id` is a registered meta (including lazy-only adds).
## @param[in]  id      Identifier to look up in BUILDMASTER_META_IDS.
## @param[out] out_var Parent-scope TRUE if present, else FALSE.
## @note Does not require `create_meta_component()`; `meta_component_add`
##       alone is enough for this to return TRUE.
function(_buildmaster_meta_is id out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_meta_is")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_is")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_is")
endfunction()

## @brief Register a meta collection (no sources; membership + INTERFACE).
## @param[in] _id              Identifier (INTERFACE target name after this call).
## @param[in] _title           Human-readable title (STATUS only).
## @param[in] options_string   Optional "KEY=value;…". Keys: INDENT / INDENT_LEVEL,
##            WHOLE (flag), TOOLCHAIN (inherited by members without their own),
##            LINK=<name> / LINK={name;name2} (raw linker names on the meta
##            INTERFACE; same contract as on a concrete component),
##            LINKFLAGS=<flag> / LINKFLAGS={…} (raw linker flags on the meta
##            INTERFACE via target_link_options; platform groups WINDOWS /
##            LINUX / MAC / UNIX).
## @note Creates an empty INTERFACE `<id>` before return so ALIAS /
##       target_* in the same CMakeLists (before DEFER) see the target.
##       `_buildmaster_materialize_metas` wires members / WHOLE / LINK /
##       LINKFLAGS onto that existing target (`if(NOT TARGET)` only covers
##       lazy metas that never called create_meta_component).
## @note RENAME / BUILDONLY / STRIPRES → INFO, ignored (meta produces no
##       archives). STRIPRES default is ON; the INFO fires only when the
##       user actually wrote the key, same as RENAME.
## @note `LINK` is accepted. Items are raw linker names, applied INTERFACE on
##       `<id>` at materialize so every consumer of the meta (and the final
##       artefact) pulls them. They do not rewrite member archives. Use this
##       to declare syslibs once for a collection instead of repeating LINK
##       on every member.
## @note `LINKFLAGS` is accepted. Items are raw linker flags, applied
##       INTERFACE on `<id>` via `target_link_options` at materialize so
##       every consumer of the meta pulls them. They do not rewrite member
##       archives.
## @note `PC` / `PC={…}` is FATAL on a meta. A collection has no single library
##       contract; flattening members into one `.pc` would invent an unbounded
##       Requires list and collide with upstream `.pc` files the author did
##       not choose. Put `PC={…}` on the concrete components you want.
## @note TOOLCHAIN does not compile the meta. Finalize copies it onto
##       `meta_component_add` members and onto `component_dependency` /
##       `component_link` dests from this meta when those dests have no
##       TOOLCHAIN yet. Two metas assigning different profiles to the same
##       dest is FATAL.
## @note May be called after meta_component_add() for the same id (fills title
##       and options). A second create_meta_component() for the same id is FATAL.
## @note If never called, lazy ids from meta_component_add() still materialize
##       with title = id, WHOLE off, TOOLCHAIN empty, LINK empty, LINKFLAGS empty.
function(create_meta_component _id _title)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_meta_component")
	if(ARGC GREATER 3)
		buildmaster_message(COMPONENT FATAL
			"create_meta_component: too many arguments (expected at most one options string).")
	endif()
	if("${_id}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL "create_meta_component: empty id")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT FATAL
			"create_meta_component('${_id}'): called after finalize")
	endif()

	get_property(_comp_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_comp_ids)
		list(FIND _comp_ids "${_id}" _cidx)
		if(NOT _cidx EQUAL -1)
			buildmaster_message(COMPONENT FATAL
				"create_meta_component: '${_id}' is already a create_*_component id")
		endif()
	endif()

	_buildmaster_meta_ensure("${_id}")
	get_property(_created GLOBAL PROPERTY BUILDMASTER_META_${_id}_CREATED)
	if(_created)
		buildmaster_message(COMPONENT FATAL
			"create_meta_component: duplicate id '${_id}'")
	endif()

	set(_optstr "")
	if(ARGC GREATER 2)
		set(_optstr "${ARGV2}")
	endif()

	buildmaster_parse_component_options(
		_indent _tc _rename _buildonly _whole _stripres "${_optstr}")
	buildmaster_parse_component_pc(
		"${_optstr}" _pc_present _pc_enabled _pc_name _pc_ver _pc_desc)
	buildmaster_parse_component_link("${_optstr}" _meta_link)
	buildmaster_parse_component_linkflags("${_optstr}" _meta_linkflags)
	if(_pc_present)
		buildmaster_message(COMPONENT FATAL
			"create_meta_component('${_id}'): PC={…} is not allowed on a meta (unbounded Requires / clash with upstream .pc). Set PC on the concrete member components instead.")
	endif()
	if(_buildonly)
		buildmaster_message(COMPONENT INFO
			"create_meta_component('${_id}'): BUILDONLY ignored (meta does not install artifacts)")
	endif()
	if("${_optstr}" MATCHES "[Rr][Ee][Nn][Aa][Mm][Ee]")
		buildmaster_message(COMPONENT INFO
			"create_meta_component('${_id}'): RENAME ignored (meta has no produced archives)")
	endif()
	if("${_optstr}" MATCHES "[Ss][Tt][Rr][Ii][Pp][Rr][Ee][Ss]")
		buildmaster_message(COMPONENT INFO
			"create_meta_component('${_id}'): STRIPRES ignored (meta has no produced archives)")
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

	add_library("${_id}" INTERFACE)

	_buildmaster_component_defer_arm()
	if(_meta_link OR _meta_linkflags)
		buildmaster_message(COMPONENT DEBUG
			"Registered meta ${_id} LINK=${_meta_link} LINKFLAGS=${_meta_linkflags}")
	else()
		buildmaster_message(COMPONENT DEBUG "Registered meta ${_id}")
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_meta_component")
endfunction()

## @brief Declare membership of one or more ids in a meta collection.
## @param[in] meta    Meta id (created lazily if create_meta_component was not
##                    called yet).
## @param[in] ARGN    Member ids (components, other metas). Duplicates are
##                    ignored. Order of first addition is flatten order.
## @note Membership is not consumption. Nothing compiles the collection until
##       some consumer component_link / component_dependency / host
##       target_link_libraries points at the meta.
function(meta_component_add meta)
	buildmaster_message(COMPONENT LOWLEVEL "Entering meta_component_add")
	if("${meta}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL "meta_component_add: empty meta id")
	endif()
	if(ARGC LESS 2)
		buildmaster_message(COMPONENT FATAL
			"meta_component_add: need at least one member")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT FATAL
			"meta_component_add: called after finalize")
	endif()

	get_property(_comp_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_comp_ids)
		list(FIND _comp_ids "${meta}" _cidx)
		if(NOT _cidx EQUAL -1)
			buildmaster_message(COMPONENT FATAL
				"meta_component_add: '${meta}' is a create_*_component id, not a meta")
		endif()
	endif()

	_buildmaster_meta_ensure("${meta}")

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
			buildmaster_message(COMPONENT FATAL
				"meta_component_add('${meta}', '${_m}'): a meta cannot contain itself")
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

	_buildmaster_component_defer_arm()
	buildmaster_message(COMPONENT DEBUG "meta_component_add ${meta} members=${_members}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting meta_component_add")
endfunction()

## @brief DFS: expand meta membership to real component leaves; FATAL on cycles.
## @param[in]  id       Meta id to expand.
## @param[in]  stack    Semicolon list of ancestors (cycle path).
## @param[out] out_var  Parent-scope list of component ids (declaration order).
function(_buildmaster_meta_collect_leaves id stack out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_meta_collect_leaves")
	_buildmaster_meta_is("${id}" _is_meta)
	if(NOT _is_meta)
		set(${out_var} "${id}" PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_collect_leaves")
		return()
	endif()

	if(stack)
		list(FIND stack "${id}" _hit)
		if(NOT _hit EQUAL -1)
			string(REPLACE ";" " → " _path "${stack}")
			buildmaster_message(COMPONENT FATAL "meta cycle: ${_path} → ${id}")
		endif()
	endif()
	list(APPEND stack "${id}")

	get_property(_members GLOBAL PROPERTY BUILDMASTER_META_${id}_MEMBERS)
	set(_leaves "")
	foreach(_m IN LISTS _members)
		if("${_m}" STREQUAL "")
			continue()
		endif()
		_buildmaster_meta_is("${_m}" _m_meta)
		if(_m_meta)
			_buildmaster_meta_collect_leaves("${_m}" "${stack}" _sub)
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_collect_leaves")
endfunction()

## @brief Materialize meta stage anchors; create INTERFACE only if missing.
## @note Runs at the start of finalize, before `create_*` materialize, so
##       `component_link` / `component_dependency` can resolve meta ids.
## @note DFS via `_buildmaster_meta_collect_leaves` (cycles FATAL). Each leaf
##       must be a registered non-BUILDONLY component.
## @note `create_meta_component` already created `<id>` INTERFACE. This
##       function does `add_library(INTERFACE)` only for lazy metas
##       (`meta_component_add` without `create_meta_component`). Always
##       creates empty `<id>_install` / `_build` / `_configure` if missing.
## @note `BUILDMASTER_META_<id>_LINK` (raw linker names) is applied INTERFACE
##       on `<id>` here so consumers of the meta propagate those names to the
##       final artefact. Empty or unset LINK is a no-op.
## @note `BUILDMASTER_META_<id>_LINKFLAGS` (raw linker flags) is applied
##       INTERFACE via `target_link_options`. Empty or unset is a no-op.
## @note Does not wire member link lines yet (leaf IMPORTED targets do not exist).
function(_buildmaster_materialize_metas)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_materialize_metas")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(NOT _metas)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_materialize_metas")
		return()
	endif()

	foreach(_id IN LISTS _metas)
		_buildmaster_meta_collect_leaves("${_id}" "" _leaves)
		set_property(GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES "${_leaves}")

		foreach(_leaf IN LISTS _leaves)
			_buildmaster_component_is_registered("${_leaf}" _is_comp)
			if(NOT _is_comp)
				buildmaster_message(COMPONENT FATAL
					"meta_component_add('${_id}', '${_leaf}'): cannot resolve member. Accepted: registered component id or another meta id.")
			endif()
			_buildmaster_component_is_buildonly("${_leaf}" _bo)
			if(_bo)
				buildmaster_message(COMPONENT FATAL
					"meta_component_add('${_id}', '${_leaf}'): BUILDONLY components cannot be meta members")
			endif()
		endforeach()

		if(NOT TARGET "${_id}")
			add_library(${_id} INTERFACE)
		endif()
		get_property(_meta_link GLOBAL PROPERTY BUILDMASTER_META_${_id}_LINK)
		if(_meta_link)
			target_link_libraries(${_id} INTERFACE ${_meta_link})
			buildmaster_message(COMPONENT DEBUG "${_id}: LINK (raw) → ${_meta_link}")
		endif()
		get_property(_meta_linkflags GLOBAL PROPERTY BUILDMASTER_META_${_id}_LINKFLAGS)
		if(_meta_linkflags)
			target_link_options(${_id} INTERFACE ${_meta_linkflags})
			buildmaster_message(COMPONENT DEBUG "${_id}: LINKFLAGS (raw) → ${_meta_linkflags}")
		endif()
		if(NOT TARGET "${_id}_install")
			add_custom_target(${_id}_install)
		endif()
		# Alias names some graphs expect; no configure/build work.
		if(NOT TARGET "${_id}_build")
			add_custom_target(${_id}_build)
			add_dependencies(${_id}_build ${_id}_install)
		endif()
		if(NOT TARGET "${_id}_configure")
			add_custom_target(${_id}_configure)
			add_dependencies(${_id}_build ${_id}_configure)
		endif()
	endforeach()
	buildmaster_message(COMPONENT DEBUG "Materialized metas: ${_metas}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_materialize_metas")
endfunction()

## @brief After real components exist: wire `<meta>_install` and INTERFACE.
## @note For each leaf, `add_dependencies(<meta>_install <leaf>_install)`.
## @note If the meta has WHOLE: flatten static produced files into one linear
##       whole-archive group; already-WHOLE children keep their own INTERFACE
##       region; shared/headers children are linked as INTERFACE only.
## @note Without WHOLE: `target_link_libraries(<meta> INTERFACE <leaf>)`.
## @note WHOLE with no static produced archives among members → INFO.
function(_buildmaster_meta_wire)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_meta_wire")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	if(NOT _metas)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_wire")
		return()
	endif()

	foreach(_id IN LISTS _metas)
		get_property(_leaves GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES)
		get_property(_whole GLOBAL PROPERTY BUILDMASTER_META_${_id}_WHOLE)

		foreach(_leaf IN LISTS _leaves)
			if(TARGET "${_leaf}_install")
				add_dependencies(${_id}_install ${_leaf}_install)
			endif()
		endforeach()

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
				_buildmaster_whole_archive_link_items(_witems ${_paths})
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
					buildmaster_message(COMPONENT INFO
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
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_meta_wire")
endfunction()

## @brief Warn once about registered components/metas with no consumer.
## @note Membership is not consumption for the meta itself, but:
##       - leaves of any meta are not orphans;
##       - a nested meta is consumed if an ancestor meta is consumed;
##       - component_repack *inputs* are consumed only if that repack id
##         itself is consumed; an unused repack orphans both itself and
##         inputs that nothing else consumes;
##       - host target_link_libraries to a component/meta id counts;
##       - host add_dependencies / custom-target DEPENDS on <id>,
##         <id>_install, <id>_build or <id>_configure counts (smoke,
##         BUILDONLY stages that never enter a link line).
function(_buildmaster_warn_orphans)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_warn_orphans")
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
				_buildmaster_meta_is("${_mem}" _mem_meta)
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
		buildmaster_message(COMPONENT WARNING
			"orphan component(s) / meta(s) (not consumed by component_link / component_dependency / host link / host DEPENDS / used repack): ${_list}")
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_warn_orphans")
endfunction()
