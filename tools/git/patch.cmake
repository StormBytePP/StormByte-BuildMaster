# =============================================================================
# tools/git/patch.cmake — buildmaster_git_patch
# =============================================================================

## @brief Queue git patches for configure-time apply; register post-install reset.
## @param[in] _component_id Component identifier (ties to install reset / clean).
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @param[in] _git_patches  List of patch files (joined with spaces for apply).
## @note Does not apply inside this function's first lines; it queues the
##       script and flushes the repo immediately so the working tree is
##       patched before any later nested cmake/meson (eager finalize).
##       If a reset is also queued for this root, flush runs reset then
##       patch once. A SOURCE_DIR DEFER remains as a fallback when no
##       component finalize runs. Paths are written without extra quote
##       wrapping (`_bm_list_join` would nest quotes inside the STATUS string
##       and break CMake parse).
function(buildmaster_git_patch _component_id _title _git_repo_dir _git_patches)
	_bm_log_message(GIT LOWLEVEL "Entering buildmaster_git_patch")
	set(GIT_REPO "${_git_repo_dir}")
	set(_patches "${_git_patches}")
	string(REPLACE ";" " " GIT_PATCHES "${_patches}")
	string(REPLACE ";" ", " GIT_PATCHES_DISPLAY "${_patches}")
	_bm_path_sanitize(_safe "${_component_id}_${_title}")
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
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_FLUSHED_${_root} FALSE)
	_bm_git_register_op("${_component_id}" "${_git_repo_dir}")
	_bm_git_flush_repo("${_git_repo_dir}")
	cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
		CALL _bm_git_flush_repo "${_git_repo_dir}")
	_bm_log_message(GIT DEBUG "Queued git patch for ${_component_id}")
	_bm_log_message(GIT LOWLEVEL "Exiting buildmaster_git_patch")
endfunction()
