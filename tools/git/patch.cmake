## @brief Queue git patches for configure-time apply; register post-install reset.
## @param[in] _component_id Component identifier (ties to install reset / clean).
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @param[in] _git_patches  List of patch files (joined with spaces for apply).
## @note Queues one script for this list. Does **not** flush and does
##       **not** reset. Flush is `_bm_git_flush_repo`: resets already
##       consumed stay consumed; this call only reopens the patch half
##       (`BUILDMASTER_GIT_PATCH_FLUSHED_<root>` = FALSE).
## @note Script name includes a hash of the patch list so two PATCH
##       batches with the same TITLE do not overwrite each other.
## @note Post-install reset is registered **here only**. A PATCH dirties
##       the srcdir for the compile; install must restore it. FETCH /
##       SWITCH / RESET-only do not write that marker.
## @note `_git_repo_dir` must be the component work tree
##       (`_bm_git_require_component_root`).
## @note Status lines show paths relative to `CMAKE_SOURCE_DIR` when the
##       patch lives under the host project. Absolute path is unchanged
##       if the file is outside that tree.
function(_bm_tools_git_patch _component_id _title _git_repo_dir _git_patches)
	_bm_log_message(GIT LOWLEVEL "Entering _bm_tools_git_patch")
	_bm_git_require_component_root("${_git_repo_dir}")
	set(GIT_REPO "${_git_repo_dir}")
	set(_patches "${_git_patches}")
	string(REPLACE ";" " " GIT_PATCHES "${_patches}")
	set(_display "")
	foreach(_p IN LISTS _patches)
		if(_p STREQUAL "")
			continue()
		endif()
		get_filename_component(_abs "${_p}" ABSOLUTE)
		file(RELATIVE_PATH _rel "${CMAKE_SOURCE_DIR}" "${_abs}")
		if(_rel MATCHES "^\\.\\.")
			set(_show "${_abs}")
		else()
			set(_show "${_rel}")
		endif()
		if(_display STREQUAL "")
			set(_display "${_show}")
		else()
			string(APPEND _display ", ${_show}")
		endif()
	endforeach()
	set(GIT_PATCHES_DISPLAY "${_display}")
	string(SHA1 _phash "${_patches}")
	_bm_path_sanitize(_safe "${_component_id}_${_title}_${_phash}")
	set(_GIT_PATCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_patch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/templates/patch.cmake.in"
		"${_GIT_PATCH_FILE}"
		@ONLY
	)
	_bm_git_toplevel(_root "${_git_repo_dir}")
	get_property(_plist GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_SCRIPTS_${_root})
	list(APPEND _plist "${_GIT_PATCH_FILE}")
	list(REMOVE_DUPLICATES _plist)
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_SCRIPTS_${_root} "${_plist}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_GIT_FLUSH_ROOTS "${_root}")
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_FLUSHED_${_root} FALSE)
	_bm_git_register_op("${_component_id}" "${_git_repo_dir}")
	_bm_git_register_post_install_reset("${_root}")
	cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
		CALL _bm_git_flush_repo "${_git_repo_dir}")
	_bm_log_message(GIT DEBUG "Queued git patch for ${_component_id}")
	_bm_log_message(GIT LOWLEVEL "Exiting _bm_tools_git_patch")
endfunction()
