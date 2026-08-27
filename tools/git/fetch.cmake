# =============================================================================
# tools/git/fetch.cmake — create_git_fetch
# =============================================================================

## @brief git fetch at parent configure; register post-install reset.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @note Generates the script and include()s it immediately. No out-variable.
function(create_git_fetch _component_id _title _git_repo_dir)
	buildmaster_message(GIT LOWLEVEL "Entering create_git_fetch")
	set(GIT_REPO "${_git_repo_dir}")
	sanitize_for_filename(_safe "${_component_id}_${_title}")
	set(_GIT_FETCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_fetch_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/fetch.cmake.in"
		"${_GIT_FETCH_FILE}"
		@ONLY
	)
	include("${_GIT_FETCH_FILE}")
	_buildmaster_git_register_op("${_component_id}" "${_git_repo_dir}")
	buildmaster_message(GIT DEBUG "Fetched git for ${_component_id}")
	buildmaster_message(GIT LOWLEVEL "Exiting create_git_fetch")
endfunction()
