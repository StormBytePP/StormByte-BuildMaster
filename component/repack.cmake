# =============================================================================
# component/repack.cmake — meta REPACK merge into the install prefix
# =============================================================================
# Included from component/helpers.cmake after the component registry exists.
# Public buildmaster_repack() is gone. Optstr REPACK on buildmaster_meta()
# registers a merge of that meta's member leaves.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

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
		_bm_log_message(COMPONENT DEBUG
			"REPACK meta ${_id} leaves=${_leaves}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_register_metas")
endfunction()

## @brief Resolve one leaf id into archives and a wait target.
## @param[in]  token    Registered component id.
## @param[out] out_files Parent-scope list of static archive paths.
## @param[out] out_deps  Parent-scope wait targets (`_build` or `_install`).
## @note BUILDONLY → files under the component BUILDDIR, wait `_build`.
##       Otherwise → files under BUILDMASTER_INSTALL_LIBDIR, wait `_install`.
##       Shared / headers contribute no files (wire already warned / linked).
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
	_bm_graph_is_buildonly("${token}" _bo)

	if(_mode STREQUAL "headers")
		set(${out_files} "" PARENT_SCOPE)
		set(${out_deps} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_resolve_input")
		return()
	endif()
	if(_mode STREQUAL "shared")
		set(${out_files} "" PARENT_SCOPE)
		set(${out_deps} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_resolve_input")
		return()
	endif()

	if(_bo)
		set(_root "${_builddir}")
		if(TARGET "${token}_build")
			list(APPEND _deps "${token}_build")
		endif()
	else()
		set(_root "${BUILDMASTER_INSTALL_LIBDIR}")
		if(TARGET "${token}_install")
			list(APPEND _deps "${token}_install")
		endif()
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

## @brief Create merge commands and attach the archive to each REPACK meta.
## @note Called from `_bm_materialize_finalize` after real components exist.
## @note Zero static inputs: WARNING, no merge (shared members already
##       INTERFACE-linked by `_bm_meta_wire`).
## @note `<id>_install` already exists from `_bm_meta_materialize`. The
##       merge file is a custom command OUTPUT; a `<id>_merge` target
##       depends on that file and `<id>_install` depends on `<id>_merge`.
##       `add_dependencies` cannot take a filesystem path.
function(_bm_repack_materialize)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_repack_materialize")
	_bm_repack_register_metas()

	get_property(_rids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
	if(NOT _rids)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_materialize")
		return()
	endif()

	set(_merge_script
		"${BUILDMASTER_SRCDIR}/tools/bundle/merge_static_archives.cmake")
	if(NOT EXISTS "${_merge_script}")
		_bm_log_message(COMPONENT FATAL "missing ${_merge_script}")
	endif()

	foreach(_id IN LISTS _rids)
		get_property(_out_name GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_OUTPUT)
		get_property(_inputs GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_INPUTS)

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
				"meta '${_id}': REPACK produced no static archive to merge (members are shared/headers only); consumers will link those members separately")
			continue()
		endif()

		_bm_lib_import_static_hint(_out_path "${_out_name}"
			"${BUILDMASTER_INSTALL_LIBDIR}" "")

		set(_inputs_joined "${_all_files}")
		string(REPLACE ";" "," _inputs_joined "${_inputs_joined}")

		set(_ar_arg "")
		if(CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
			set(_ar_arg "-DCMAKE_AR=${CMAKE_AR}")
		endif()

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

		set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${_id}_FILE "${_out_path}")
		_bm_log_message(COMPONENT DEBUG "Materialized REPACK ${_id} → ${_out_path}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_repack_materialize")
endfunction()
