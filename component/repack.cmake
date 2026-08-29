# =============================================================================
# component/repack.cmake — component_repack (static merge into install prefix)
# =============================================================================
# Included from component/helpers.cmake after the component registry exists.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief Register a static archive merge published under the install prefix.
## @param[in] id Short pack identifier (INTERFACE target name after finalize).
## @param[in] OUTPUT Canonical library basename without prefix/suffix
##            (e.g. `x265`, `mergedlib`), written under BUILDMASTER_INSTALL_LIBDIR.
## @param[in] INPUTS List of tokens (semicolon-separated or multiple args):
##            - registered component id → all produced canons under that
##              component BUILDDIR (post-RENAME);
##            - existing CMake target → order only (no files);
##            - filesystem path → that archive + file-level DEPENDS.
## @note Does not install inputs to the prefix. Component inputs contribute
##       BUILDDIR produced paths; custom targets contribute order only.
## @note Creates `<id>_install` as the graph anchor (DEPENDS the merged OUTPUT)
##       so other components can component_dependency(..., id).
## @note Static archives only (v1). Uses tools/bundle/merge_static_archives.cmake
##       and buildmaster_find_archiver (CMAKE_AR, ENV{AR}, llvm-lib/lib, ar…).
## @note Duplicate id vs create_component / another repack → FATAL.
function(component_repack id)
	_bm_log_message(COMPONENT LOWLEVEL "Entering component_repack")
	if("${id}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "component_repack: empty id")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"component_repack('${id}'): called after finalize")
	endif()

	cmake_parse_arguments(ARG "" "OUTPUT" "INPUTS" ${ARGN})
	if(NOT ARG_OUTPUT)
		_bm_log_message(COMPONENT FATAL
			"component_repack('${id}'): OUTPUT is required")
	endif()
	if(NOT ARG_INPUTS)
		_bm_log_message(COMPONENT FATAL
			"component_repack('${id}'): INPUTS is required")
	endif()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			_bm_log_message(COMPONENT FATAL
				"component_repack: id '${id}' already a component")
		endif()
	endif()
	get_property(_rids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
	if(_rids)
		list(FIND _rids "${id}" _ridx)
		if(NOT _ridx EQUAL -1)
			_bm_log_message(COMPONENT FATAL
				"component_repack: duplicate id '${id}'")
		endif()
	endif()

	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_REPACK_IDS "${id}")
	set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${id}_OUTPUT "${ARG_OUTPUT}")
	set_property(GLOBAL PROPERTY BUILDMASTER_REPACK_${id}_INPUTS "${ARG_INPUTS}")

	_buildmaster_component_defer_arm()
	_bm_log_message(COMPONENT DEBUG "Registered repack ${id} OUTPUT=${ARG_OUTPUT}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting component_repack")
endfunction()

## @brief Resolve one INPUT token into files and/or order targets.
## @param[in]  token    Component id, CMake target name, or file path.
## @param[out] out_files Parent-scope list of archive paths to merge.
## @param[out] out_deps  Parent-scope list of CMake targets for ordering.
function(_buildmaster_repack_resolve_input token out_files out_deps)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_repack_resolve_input")
	set(_files "")
	set(_deps "")

	_buildmaster_component_is_registered("${token}" _is_comp)
	if(_is_comp)
		get_property(_builddir GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${token}_BUILDDIR)
		get_property(_mode GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${token}_MODE)
		get_property(_produced GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${token}_PRODUCED)
		if(_mode STREQUAL "headers")
			_bm_log_message(COMPONENT FATAL
				"component_repack: INPUT '${token}' is headers-only")
		endif()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			set(_names "")
			set(_paths "")
			set(_dlls "")
			buildmaster_append_library_spec(
				"${_mode}" "${_spec}" "${_builddir}"
				_names _paths _dlls)
			list(APPEND _files ${_paths})
		endforeach()
		# Prefer install-stage target (BUILDONLY: post-RENAME; normal: still valid
		# order node). Fall back to _build if needed.
		if(TARGET "${token}_install")
			list(APPEND _deps "${token}_install")
		elseif(TARGET "${token}_build")
			list(APPEND _deps "${token}_build")
		endif()
		set(${out_files} "${_files}" PARENT_SCOPE)
		set(${out_deps} "${_deps}" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_repack_resolve_input")
		return()
	endif()

	if(TARGET "${token}")
		list(APPEND _deps "${token}")
		set(${out_files} "" PARENT_SCOPE)
		set(${out_deps} "${_deps}" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_repack_resolve_input")
		return()
	endif()

	if(IS_ABSOLUTE "${token}" AND EXISTS "${token}" AND NOT IS_DIRECTORY "${token}")
		list(APPEND _files "${token}")
		set(${out_files} "${_files}" PARENT_SCOPE)
		set(${out_deps} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_repack_resolve_input")
		return()
	endif()

	if(EXISTS "${token}" AND NOT IS_DIRECTORY "${token}")
		get_filename_component(_abs "${token}" ABSOLUTE)
		list(APPEND _files "${_abs}")
		set(${out_files} "${_files}" PARENT_SCOPE)
		set(${out_deps} "" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_repack_resolve_input")
		return()
	endif()

	_bm_log_message(COMPONENT FATAL
		"component_repack: cannot resolve INPUT '${token}' (expected component id, CMake target, or archive path)")
endfunction()

## @brief Create merge commands, IMPORTED archives, and `<id>_install` for every
##        registered `component_repack`.
## @note Called from `_buildmaster_finalize_components` after real components
##       exist so INPUT component ids already have `_install` / `_build`.
## @note OUTPUT path is `library_import_static_hint` under
##       BUILDMASTER_INSTALL_LIBDIR. Merge runs `merge_static_archives.cmake`
##       with CMAKE_AR when set. Empty INPUT file list is FATAL.
## @note Marks BUILDMASTER_REPACK_<id>_FILE for orphan / consumption checks.
function(_buildmaster_materialize_repacks)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _buildmaster_materialize_repacks")
	get_property(_rids GLOBAL PROPERTY BUILDMASTER_REPACK_IDS)
	if(NOT _rids)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_materialize_repacks")
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
			_buildmaster_repack_resolve_input("${_tok}" _f _d)
			list(APPEND _all_files ${_f})
			list(APPEND _all_deps ${_d})
		endforeach()

		if(_all_files STREQUAL "")
			_bm_log_message(COMPONENT FATAL
				"component_repack('${_id}'): no archive files from INPUTS")
		endif()
		if(_all_deps)
			list(REMOVE_DUPLICATES _all_deps)
		endif()
		list(REMOVE_DUPLICATES _all_files)

		library_import_static_hint(_out_path "${_out_name}"
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

		add_custom_target(${_id}_install
			DEPENDS "${_out_path}"
		)
		if(_all_deps)
			add_dependencies(${_id}_install ${_all_deps})
		endif()
		if(TARGET buildmaster_build_init)
			add_dependencies(${_id}_install buildmaster_build_init)
		endif()

		if(NOT TARGET ${_id})
			add_library(${_id} INTERFACE)
			target_include_directories(${_id} SYSTEM INTERFACE
				"${BUILDMASTER_INSTALL_INCLUDEDIR}")
			add_dependencies(${_id} ${_id}_install)

			set(_imp "${_id}_merged")
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
		_bm_log_message(COMPONENT DEBUG "Materialized repack ${_id} → ${_out_path}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _buildmaster_materialize_repacks")
endfunction()
