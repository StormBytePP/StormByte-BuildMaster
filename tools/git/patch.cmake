# =============================================================================
# tools/git/patch.cmake — create_git_patch_file
# =============================================================================

## @brief Apply git patches at parent configure; register post-install reset.
## @param[in] _component_id Component identifier (ties to install reset / clean).
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @param[in] _git_patches  List of patch files (joined for the apply command).
## @note Generates the script and include()s it immediately. No out-variable.
function(create_git_patch_file _component_id _title _git_repo_dir _git_patches)
	buildmaster_message(GIT LOWLEVEL "Entering create_git_patch_file")
	set(GIT_REPO "${_git_repo_dir}")
	list_join(GIT_PATCHES "${_git_patches}" " ")
	sanitize_for_filename(_safe "${_component_id}_${_title}")
	set(_GIT_PATCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_patch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/patch.cmake.in"
		"${_GIT_PATCH_FILE}"
		@ONLY
	)
	include("${_GIT_PATCH_FILE}")
	_buildmaster_git_register_op("${_component_id}" "${_git_repo_dir}")
	buildmaster_message(GIT DEBUG "Applied git patch for ${_component_id}")
	buildmaster_message(GIT LOWLEVEL "Exiting create_git_patch_file")
endfunction()
