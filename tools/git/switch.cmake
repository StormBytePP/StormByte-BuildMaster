# =============================================================================
# tools/git/switch.cmake — _bm_tools_git_switch
# =============================================================================

## @brief Switch branch at parent configure.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @param[in] _git_branch   Branch name.
## @note Generates the script and include()s it immediately. No out-variable.
## @note Does **not** write the post-install reset marker. That is PATCH-only.
## @note `_git_repo_dir` must be the component work tree
##       (`_bm_git_require_component_root`).
function(_bm_tools_git_switch _component_id _title _git_repo_dir _git_branch)
	_bm_log_message(GIT LOWLEVEL "Entering _bm_tools_git_switch")
	_bm_git_require_component_root("${_git_repo_dir}")
	set(GIT_REPO "${_git_repo_dir}")
	set(GIT_BRANCH "${_git_branch}")
	_bm_path_sanitize(_safe "${_component_id}_${_title}")
	set(_GIT_SWITCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_switch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/templates/switch.cmake.in"
		"${_GIT_SWITCH_FILE}"
		@ONLY
	)
	include("${_GIT_SWITCH_FILE}")
	_bm_git_register_op("${_component_id}" "${_git_repo_dir}")
	_bm_log_message(GIT DEBUG "Switched ${_component_id} to ${_git_branch}")
	_bm_log_message(GIT LOWLEVEL "Exiting _bm_tools_git_switch")
endfunction()
