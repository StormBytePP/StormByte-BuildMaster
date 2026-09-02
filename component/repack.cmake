# =============================================================================
# component/repack.cmake — REPACK merge into the install prefix
# =============================================================================
# Included from component/helpers.cmake after the component registry exists.
# Public buildmaster_repack() is gone.
# Optstr REPACK on buildmaster_meta() merges that meta's member leaves
# into one prefix archive named after the meta id (OUTPUT of that path).
# Optstr REPACK on buildmaster_component() merges first-level depend/link
# dests that are NOINSTALL static into this component's already-installed
# prefix archive (POST_BUILD on <id>_install — never a second OUTPUT on
# the GNU .a; that collides with the install_exec rule).

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief First-level depend/link dests of `id` that may be REPACK members.
## @param[in]  id      Publishing component with REPACK.
## @param[out] out_var Parent-scope list of member ids (NOINSTALL static).
## @note `executable` dest is skipped (INFO). It is not a static archive
##       and must not FATAL as a “publishing member”.
## @note Publishing dest (not executable) → FATAL. Shared/headers dest → FATAL.
##       Unregistered dest is ignored (system LINK names).
function(_bm_repack_component_members id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_component_members")
	set(_mem "")
	get_property(_dsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_ddsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)

	set(_pairs "")
	set(_i 0)
	foreach(_s IN LISTS _dsrcs)
		list(GET _ddsts ${_i} _d)
		math(EXPR _i "${_i} + 1")
		if(_s STREQUAL "${id}")
			list(APPEND _pairs "${_d}")
		endif()
	endforeach()
	set(_i 0)
	foreach(_s IN LISTS _lsrcs)
		list(GET _ldsts ${_i} _d)
		math(EXPR _i "${_i} + 1")
		if(_s STREQUAL "${id}")
			list(APPEND _pairs "${_d}")
		endif()
	endforeach()
	if(_pairs)
		list(REMOVE_DUPLICATES _pairs)
	endif()

	foreach(_d IN LISTS _pairs)
		if(_d STREQUAL "" OR _d STREQUAL "${id}")
			continue()
		endif()
		_bm_graph_is_registered("${_d}" _is_c)
		if(NOT _is_c)
			continue()
		endif()
		get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_d}_MODE)
		if(_mode STREQUAL "executable")
			_bm_log_message(COMPONENT INFO
				"buildmaster_component('${id}'): REPACK ignores dest '${_d}' (executable)")
			continue()
		endif()
		_bm_graph_is_noinstall("${_d}" _ni)
		if(NOT _ni)
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component('${id}'): REPACK member '${_d}' publishes to the prefix — members must be NOINSTALL")
		endif()
		if(NOT _mode STREQUAL "static")
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component('${id}'): REPACK member '${_d}' is '${_mode}' (only static NOINSTALL)")
		endif()
		list(APPEND _mem "${_d}")
	endforeach()

	set(${out_var} "${_mem}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_component_members")
endfunction()

## @brief Register merges for every meta that has REPACK.
## @note OUTPUT stem is the meta id. INPUTS are the flattened member leaves.
##       Called at the start of `_bm_repack_materialize` (finalize).
function(_bm_repack_register_metas)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_register_metas")
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	foreach(_id IN LISTS _metas)
		if("${_id}" STREQUAL "")
			continue()
		endif()
		get_property(_repack GLOBAL PROPERTY BUILDMASTER_META_${_id}_REPACK)
		if(NOT _repack)
			continue()
		endif()
		get_property(_leaves GLOBAL PROPERTY BUILDMASTER_META_${_id}_LEAVES)
		if(NOT _leaves)
			_bm_log_message(COMPONENT FATAL
				"buildmaster_meta('${_id}'): REPACK requires at least one member (buildmaster_meta_add)")
		endif()
		get_property(_rids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
		set(_hit -1)
		if(_rids)
			list(FIND _rids "${_id}" _hit)
		endif()
		if(NOT _hit EQUAL -1)
			continue()
		endif()
		set_property(GLOBAL APPEND PROPERTY BUILDMASTER_REPACK_IDS "${_id}")
		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_OUTPUT "${_id}")
		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_INPUTS "${_leaves}")
		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_KIND "meta")
		_bm_log_message(COMPONENT DEBUG
			"REPACK meta ${_id} leaves=${_leaves}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_register_metas")
endfunction()

## @brief Register REPACK merges for components that opted in.
## @note Shared + REPACK → WARNING, skip. Zero members → FATAL.
##       OUTPUT stem is the first produced basename (prefix archive).
##       INPUTS are the publisher plus the NOINSTALL members (publisher
##       first so the merge rewrites the installed .a).
## @note KIND=component → POST_BUILD on `<id>_install`. Do not declare
##       OUTPUT of that GNU path (install_exec already owns it).
function(_bm_repack_register_components)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_register_components")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	foreach(_id IN LISTS _ids)
		if("${_id}" STREQUAL "")
			continue()
		endif()
		get_property(_repack GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_REPACK)
		if(NOT _repack)
			continue()
		endif()
		get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_MODE)
		if(NOT _mode STREQUAL "static")
			_bm_log_message(COMPONENT WARNING
				"buildmaster_component('${_id}'): REPACK ignored (mode '${_mode}'; static only)")
			continue()
		endif()
		_bm_repack_component_members("${_id}" _mem)
		if(NOT _mem)
			_bm_log_message(COMPONENT FATAL
				"buildmaster_component('${_id}'): REPACK requires at least one first-level depend/link to a NOINSTALL static component")
		endif()
		get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_PRODUCED)
		set(_out_name "")
		foreach(_spec IN LISTS _produced)
			if(NOT _spec STREQUAL "")
				_bm_opt_parse_spec("${_spec}" _ign_t _out_name _ign_d)
				break()
			endif()
		endforeach()
		if(_out_name STREQUAL "")
			set(_out_name "${_id}")
		endif()
		get_property(_rids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
		set(_hit -1)
		if(_rids)
			list(FIND _rids "${_id}" _hit)
		endif()
		if(NOT _hit EQUAL -1)
			continue()
		endif()
		set(_inputs "${_id}")
		list(APPEND _inputs ${_mem})
		set_property(GLOBAL APPEND PROPERTY BUILDMASTER_REPACK_IDS "${_id}")
		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_OUTPUT "${_out_name}")
		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_INPUTS "${_inputs}")
		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_KIND "component")
		_bm_log_message(COMPONENT DEBUG
			"REPACK component ${_id} out=${_out_name} inputs=${_inputs}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_register_components")
endfunction()

## @brief Resolve one leaf id into archives and a wait target.
## @param[in]  token    Registered component id.
## @param[out] out_files Parent-scope list of static archive paths.
## @param[out] out_deps  Parent-scope wait targets (`_install`).
## @note NOINSTALL → files under the component BUILDDIR. The
##       `<id>_install` target still runs: it does **not** call
##       `cmake --install`. It only seals oficios on the BUILDDIR
##       (rename / outputs / strip). Waiting on `_build` skips that
##       seal and REPACK sees the upstream stem (`x265-static.lib`).
## @note Installing components → files under BUILDMASTER_INSTALL_LIBDIR,
##       wait `_install` (prefix already renamed).
## @note Shared / headers / executable contribute no files.
## @todo Split the current `_install` target into explicit phases
##       (`_install` = `cmake --install` only, `_post_install` = oficios
##       + optional git reset). Rename of libraries stays **after**
##       `--install` so `install(FILES)` still sees upstream names.
##       `NOINSTALL` has no `_install` publish step; oficios stay
##       post-build on the BUILDDIR. Do not retarget in this patch.
function(_bm_repack_resolve_input token out_files out_deps)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_resolve_input")
	set(_files "")
	set(_deps "")

	_bm_graph_is_registered("${token}" _is_comp)
	if(NOT _is_comp)
		_bm_log_message(COMPONENT FATAL
			"REPACK member '${token}' is not a registered component")
	endif()

	get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${token}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${token}_PRODUCED)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${token}_BUILDDIR)
	_bm_graph_is_noinstall("${token}" _ni)

	if(_mode STREQUAL "headers"
			OR _mode STREQUAL "shared"
			OR _mode STREQUAL "executable")
		set(${out_files} "" PARENT_SCOPE)
		set(${out_deps} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_resolve_input")
		return()
	endif()

	if(_ni)
		set(_root "${_builddir}")
	else()
		set(_root "${BUILDMASTER_INSTALL_LIBDIR}")
	endif()
	if(TARGET "${token}_install")
		list(APPEND _deps "${token}_install")
	endif()

	foreach(_spec IN LISTS _produced)
		if(_spec STREQUAL "")
			continue()
		endif()
		set(_names "")
		set(_paths "")
		set(_dlls "")
		_bm_opt_append_spec(
			"${_mode}" "${_spec}" "${_root}"
			_names _paths _dlls)
		list(APPEND _files ${_paths})
	endforeach()

	set(${out_files} "${_files}" PARENT_SCOPE)
	set(${out_deps} "${_deps}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_resolve_input")
endfunction()

## @brief Archiver for a REPACK id: profile of that component, not the parent job.
## @param[in] id REPACK publisher id.
## @param[out] out_arg `-DCMAKE_AR=<abs>` or empty.
## @note OPTSTR TOOLCHAIN (including meta inherit) wins. Empty → infer from
##       this process. Short names (`lib`, `llvm-ar`) are resolved; the
##       merge script requires an existing path.
function(_bm_repack_ar_arg id out_arg)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_ar_arg(${id})")
	set(_arg "")
	set(_tc "")
	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	if(COMMAND _bm_opt_parse)
		_bm_opt_parse(_il _tc _rn _ni _wh _sr "${_optstr}")
	endif()
	if(_tc STREQUAL "" AND COMMAND _bm_tc_infer_profile)
		_bm_tc_infer_profile(_tc)
	endif()
	set(_ar "")
	if(NOT _tc STREQUAL "" AND COMMAND _bm_tc_load_profile)
		_bm_tc_load_profile("${_tc}")
		if(DEFINED BM_TC_AR)
			set(_ar "${BM_TC_AR}")
		endif()
	endif()
	if(_ar STREQUAL "" AND CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
		set(_ar "${CMAKE_AR}")
	endif()
	if(NOT _ar STREQUAL "")
		if((_tc STREQUAL "msvc" OR _tc STREQUAL "clang-cl")
				AND NOT IS_ABSOLUTE "${_ar}"
				AND COMMAND _bm_tc_resolve_msvc_tool)
			_bm_tc_resolve_msvc_tool(_ar "${_ar}")
		endif()
		if(NOT IS_ABSOLUTE "${_ar}")
			find_program(_ar_abs NAMES "${_ar}")
			if(_ar_abs)
				set(_ar "${_ar_abs}")
			endif()
			unset(_ar_abs)
		endif()
		_bm_path_normalize(_ar "${_ar}")
		set(_arg "-DCMAKE_AR=${_ar}")
	endif()
	set(${out_arg} "${_arg}" PARENT_SCOPE)
	_bm_log_message(COMPONENT DEBUG "REPACK '${id}' AR arg '${_arg}' (profile='${_tc}')")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_ar_arg(${id})")
endfunction()

## @brief Create merge commands and attach the archive to each REPACK id.
## @note Called from `_bm_materialize_finalize` after real components exist.
## @note Zero static inputs: WARNING, no merge (shared members already
##       INTERFACE-linked by `_bm_meta_wire`).
## @note Meta KIND: `<id>_install` already exists from `_bm_meta_materialize`.
##       The merge file is a custom command OUTPUT; `<id>_merge` depends
##       on that file and `<id>_install` depends on `<id>_merge`.
## @note Component KIND: POST_BUILD on the existing `<id>_install`.
##       Consumers already wait on `<id>_install`, so they see the merged
##       archive. No extra OUTPUT on the GNU path.
## @note `-DCMAKE_AR=` comes from `_bm_repack_ar_arg` (publisher profile),
##       not from the parent job's `CMAKE_AR`.
function(_bm_repack_materialize)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_materialize")
	_bm_repack_register_metas()
	_bm_repack_register_components()

	get_property(_rids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
	if(NOT _rids)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_materialize")
		return()
	endif()

	set(_merge_script
		"${BUILDMASTER_SRCDIR}/component/bundle/merge_static_archives.cmake")
	if(NOT EXISTS "${_merge_script}")
		_bm_log_message(COMPONENT FATAL "missing ${_merge_script}")
	endif()

	foreach(_id IN LISTS _rids)
		get_property(_out_name GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_OUTPUT)
		get_property(_inputs GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_INPUTS)
		get_property(_kind GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_KIND)
		if(_kind STREQUAL "")
			set(_kind "meta")
		endif()

		set(_all_files "")
		set(_all_deps "")
		foreach(_tok IN LISTS _inputs)
			string(STRIP "${_tok}" _tok)
			if(_tok STREQUAL "")
				continue()
			endif()
			_bm_repack_resolve_input("${_tok}" _f _d)
			list(APPEND _all_files ${_f})
			list(APPEND _all_deps ${_d})
		endforeach()

		if(_all_deps)
			list(REMOVE_DUPLICATES _all_deps)
		endif()
		if(_all_files)
			list(REMOVE_DUPLICATES _all_files)
		endif()

		if(_all_files STREQUAL "")
			_bm_log_message(COMPONENT WARNING
				"REPACK '${_id}': produced no static archive to merge (members are shared/headers only); consumers will link those members separately")
			continue()
		endif()

		_bm_lib_import_static_hint(_out_path "${_out_name}"
			"${BUILDMASTER_INSTALL_LIBDIR}" "")

		set(_inputs_joined "${_all_files}")
		string(REPLACE ";" "," _inputs_joined "${_inputs_joined}")

		_bm_repack_ar_arg("${_id}" _ar_arg)

		if(_kind STREQUAL "component")
			if(NOT TARGET ${_id}_install)
				_bm_log_message(COMPONENT FATAL
					"REPACK component '${_id}': missing ${_id}_install")
			endif()
			add_custom_command(
				TARGET ${_id}_install POST_BUILD
				COMMAND ${CMAKE_COMMAND}
					"-DOUTPUT=${_out_path}"
					"-DINPUTS=${_inputs_joined}"
					"-DBUILDMASTER_SRCDIR=${BUILDMASTER_SRCDIR}"
					${_ar_arg}
					-P "${_merge_script}"
				COMMENT "[BuildMaster/Component]: Repacking ${_id} → ${_out_name}"
				VERBATIM
			)
			if(_all_deps)
				add_dependencies(${_id}_install ${_all_deps})
			endif()
		else()
			add_custom_command(
				OUTPUT "${_out_path}"
				COMMAND ${CMAKE_COMMAND}
					"-DOUTPUT=${_out_path}"
					"-DINPUTS=${_inputs_joined}"
					"-DBUILDMASTER_SRCDIR=${BUILDMASTER_SRCDIR}"
					${_ar_arg}
					-P "${_merge_script}"
				DEPENDS ${_all_files}
				COMMENT "[BuildMaster/Component]: Repacking ${_id} → ${_out_name}"
				VERBATIM
			)

			if(NOT TARGET ${_id}_merge)
				add_custom_target(${_id}_merge DEPENDS "${_out_path}")
			endif()
			if(NOT TARGET ${_id}_install)
				add_custom_target(${_id}_install)
			endif()
			add_dependencies(${_id}_install ${_id}_merge)
			if(_all_deps)
				add_dependencies(${_id}_install ${_all_deps})
				add_dependencies(${_id}_merge ${_all_deps})
			endif()
			if(TARGET buildmaster_build_init)
				add_dependencies(${_id}_install buildmaster_build_init)
			endif()

			if(NOT TARGET ${_id})
				add_library(${_id} INTERFACE)
				target_include_directories(${_id} SYSTEM INTERFACE
					"${BUILDMASTER_INSTALL_INCLUDEDIR}")
			endif()
			add_dependencies(${_id} ${_id}_install)

			set(_imp "${_id}_merged")
			if(NOT TARGET ${_imp})
				add_library(${_imp} STATIC IMPORTED GLOBAL)
				set_target_properties(${_imp} PROPERTIES
					IMPORTED_LOCATION "${_out_path}"
					IMPORTED_LOCATION_DEBUG "${_out_path}"
					IMPORTED_LOCATION_RELEASE "${_out_path}"
					IMPORTED_LOCATION_MINSIZEREL "${_out_path}"
					IMPORTED_LOCATION_RELWITHDEBINFO "${_out_path}"
				)
				add_dependencies(${_imp} ${_id}_install)
				target_link_libraries(${_id} INTERFACE ${_imp})
			endif()
		endif()

		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_FILE "${_out_path}")
		_bm_log_message(COMPONENT DEBUG "Materialized REPACK ${_id} → ${_out_path}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_materialize")
endfunction()
