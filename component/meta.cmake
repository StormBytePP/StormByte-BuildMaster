# =============================================================================
# component/meta.cmake — meta components (INTERFACE collections, no sources)
# =============================================================================
# Public: buildmaster_meta, buildmaster_meta_add
# Children: materialize + wire (from helpers). Finalize calls those.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/meta/helpers.cmake")

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

## @brief Declare a meta component (INTERFACE collection, optional REPACK).
## @param[in] _id     Meta identifier (also the REPACK archive stem).
## @param[in] _title  Human-readable title.
## @param[in] ARGV2   Optional options string (`WHOLE`, `REPACK`, `LINK=`,
##                    `LINKFLAGS=`, `TOOLCHAIN=`, `INDENT=`).
## @note `REPACK` merges every produced *static* archive of the member leaves
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
## @note `FILES={…}` is FATAL on a meta (no srcdir, no configure). Empty
##       `FILES` / `FILES={}` is still FATAL here: a leftover on a meta is
##       not a download.
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
	_bm_opt_parse_files(
		"${_optstr}" _files_present
		_files_urls _files_names _files_hashes _files_algos
		_files_unpacks _files_forces _files_sources _files_titles)
	_bm_opt_parse_repack("${_optstr}" _repack)
	if(_pc_present)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta('${_id}'): PC={…} is not allowed on a meta (unbounded Requires / clash with upstream .pc). Set PC on the concrete member components instead.")
	endif()
	if(_git_present AND (_git_fetch OR NOT "${_git_switch}" STREQUAL "" OR _git_reset OR _git_patches))
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta('${_id}'): cannot run git commands on a sourceless meta component")
	endif()
	if(_files_present)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_meta('${_id}'): FILES={…} is not allowed on a meta (no srcdir, no configure)")
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
