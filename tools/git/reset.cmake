# =============================================================================
# tools/git/reset.cmake — create_git_reset_file
# =============================================================================

## @brief git reset --hard + clean -fd at parent configure; register post-install.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @note Generates the script and include()s it immediately. **No out-variable.**
##       Call as: `create_git_reset_file(<id> <title> <repo>)`.
function(create_git_reset_file _component_id _title _git_repo_dir)
	buildmaster_message(GIT LOWLEVEL "Entering create_git_reset_file")
	set(GIT_REPO "${_git_repo_dir}")
	sanitize_for_filename(_safe "${_component_id}_${_title}")
	set(_GIT_RESET_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_reset_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/reset.cmake.in"
		"${_GIT_RESET_FILE}"
		@ONLY
	)
	include("${_GIT_RESET_FILE}")
	_buildmaster_git_register_op("${_component_id}" "${_git_repo_dir}")
	buildmaster_message(GIT DEBUG "Reset git repo for ${_component_id}")
	buildmaster_message(GIT LOWLEVEL "Exiting create_git_reset_file")
endfunction()
