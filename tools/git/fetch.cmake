# =============================================================================
# tools/git/fetch.cmake — _bm_tools_git_fetch
# =============================================================================

## @brief git fetch at parent configure.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @note Generates the script and include()s it immediately. No out-variable.
## @note Does **not** write the post-install reset marker. That is PATCH-only.
function(_bm_tools_git_fetch _component_id _title _git_repo_dir)
	_bm_log_message(GIT LOWLEVEL "Entering _bm_tools_git_fetch")
	set(GIT_REPO "${_git_repo_dir}")
	_bm_path_sanitize(_safe "${_component_id}_${_title}")
	set(_GIT_FETCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_fetch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/templates/fetch.cmake.in"
		"${_GIT_FETCH_FILE}"
		@ONLY
	)
	include("${_GIT_FETCH_FILE}")
	_bm_git_register_op("${_component_id}" "${_git_repo_dir}")
	_bm_log_message(GIT DEBUG "Fetched git for ${_component_id}")
	_bm_log_message(GIT LOWLEVEL "Exiting _bm_tools_git_fetch")
endfunction()
