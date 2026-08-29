# =============================================================================
# tools/git/switch.cmake — create_git_switch_branch
# =============================================================================

## @brief Switch branch at parent configure; register post-install reset.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @param[in] _git_branch   Branch name.
## @note Generates the script and include()s it immediately. No out-variable.
function(create_git_switch_branch _component_id _title _git_repo_dir _git_branch)
	_bm_log_message(GIT LOWLEVEL "Entering create_git_switch_branch")
	set(GIT_REPO "${_git_repo_dir}")
	set(GIT_BRANCH "${_git_branch}")
	sanitize_for_filename(_safe "${_component_id}_${_title}")
	set(_GIT_SWITCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_switch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/switch.cmake.in"
		"${_GIT_SWITCH_FILE}"
		@ONLY
	)
	include("${_GIT_SWITCH_FILE}")
	_buildmaster_git_register_op("${_component_id}" "${_git_repo_dir}")
	_bm_log_message(GIT DEBUG "Switched ${_component_id} to ${_git_branch}")
	_bm_log_message(GIT LOWLEVEL "Exiting create_git_switch_branch")
endfunction()
