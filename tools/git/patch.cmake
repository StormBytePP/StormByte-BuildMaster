# =============================================================================
# tools/git/patch.cmake — create_git_patch_file
# =============================================================================

## @brief Apply git patches at parent configure; register post-install reset.
## @param[in] _component_id Component identifier (ties to install reset / clean).
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @param[in] _git_patches  List of patch files (joined with spaces for apply).
## @note Generates the script and queues it. Flush is reset-then-patch for the
##       repo. Paths are written without extra quote wrapping (`list_join` would
##       nest quotes inside the STATUS string and break CMake parse).
function(create_git_patch_file _component_id _title _git_repo_dir _git_patches)
	buildmaster_message(GIT LOWLEVEL "Entering create_git_patch_file")
	set(GIT_REPO "${_git_repo_dir}")
	set(_patches "${_git_patches}")
	string(REPLACE ";" " " GIT_PATCHES "${_patches}")
	string(REPLACE ";" ", " GIT_PATCHES_DISPLAY "${_patches}")
	sanitize_for_filename(_safe "${_component_id}_${_title}")
	set(_GIT_PATCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_patch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/patch.cmake.in"
		"${_GIT_PATCH_FILE}"
		@ONLY
	)
	_buildmaster_git_toplevel(_root "${_git_repo_dir}")
	get_property(_plist GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_SCRIPTS_${_root})
	list(APPEND _plist "${_GIT_PATCH_FILE}")
	list(REMOVE_DUPLICATES _plist)
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_SCRIPTS_${_root} "${_plist}")
	_buildmaster_git_register_op("${_component_id}" "${_git_repo_dir}")
	_buildmaster_git_flush_repo("${_git_repo_dir}")
	buildmaster_message(GIT DEBUG "Applied git patch for ${_component_id}")
	buildmaster_message(GIT LOWLEVEL "Exiting create_git_patch_file")
endfunction()
