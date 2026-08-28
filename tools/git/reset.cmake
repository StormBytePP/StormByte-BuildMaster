# =============================================================================
# tools/git/reset.cmake — create_git_reset_file
# =============================================================================

## @brief Run queued reset scripts then queued patch scripts for one git root.
## @param[in] _git_repo_dir Repository or worktree path.
## @note Resets always run first. Safe to call more than once for the same root.
function(_buildmaster_git_flush_repo _git_repo_dir)
	_buildmaster_git_toplevel(_root "${_git_repo_dir}")
	get_property(_resets GLOBAL PROPERTY BUILDMASTER_GIT_RESET_SCRIPTS_${_root})
	get_property(_patches GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_SCRIPTS_${_root})
	foreach(_s IN LISTS _resets)
		if(EXISTS "${_s}")
			include("${_s}")
		endif()
	endforeach()
	foreach(_s IN LISTS _patches)
		if(EXISTS "${_s}")
			include("${_s}")
		endif()
	endforeach()
endfunction()

## @brief git reset --hard + clean -fd at parent configure; register post-install.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @note Generates the script and queues it. Flush runs every reset for the
##       repo, then every patch, so call order of create_git_* does not matter.
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
	_buildmaster_git_toplevel(_root "${_git_repo_dir}")
	get_property(_resets GLOBAL PROPERTY BUILDMASTER_GIT_RESET_SCRIPTS_${_root})
	list(APPEND _resets "${_GIT_RESET_FILE}")
	list(REMOVE_DUPLICATES _resets)
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_RESET_SCRIPTS_${_root} "${_resets}")
	_buildmaster_git_register_op("${_component_id}" "${_git_repo_dir}")
	_buildmaster_git_flush_repo("${_git_repo_dir}")
	buildmaster_message(GIT DEBUG "Reset git repo for ${_component_id}")
	buildmaster_message(GIT LOWLEVEL "Exiting create_git_reset_file")
endfunction()
