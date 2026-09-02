# =============================================================================
# tools/git/reset.cmake — _bm_tools_git_reset
# =============================================================================

## @brief Run queued reset scripts for one git root (once per queue).
## @param[in] _git_repo_dir Repository or worktree path.
## @note No-op until a new reset script is queued (flag cleared there).
function(_bm_git_flush_resets _git_repo_dir)
	_bm_git_toplevel(_root "${_git_repo_dir}")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_GIT_RESET_FLUSHED_${_root})
	if(_done)
		return()
	endif()
	get_property(_resets GLOBAL PROPERTY BUILDMASTER_GIT_RESET_SCRIPTS_${_root})
	foreach(_s IN LISTS _resets)
		if(EXISTS "${_s}")
			include("${_s}")
		endif()
	endforeach()
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_RESET_FLUSHED_${_root} TRUE)
endfunction()

## @brief Run queued patch scripts for one git root (once per queue).
## @param[in] _git_repo_dir Repository or worktree path.
## @note No-op until a new patch script is queued (flag cleared there).
##       Does not reset.
function(_bm_git_flush_patches _git_repo_dir)
	_bm_git_toplevel(_root "${_git_repo_dir}")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_FLUSHED_${_root})
	if(_done)
		return()
	endif()
	get_property(_patches GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_SCRIPTS_${_root})
	foreach(_s IN LISTS _patches)
		if(EXISTS "${_s}")
			include("${_s}")
		endif()
	endforeach()
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_PATCH_FLUSHED_${_root} TRUE)
endfunction()

## @brief Run queued resets then queued patches for one git root.
## @param[in] _git_repo_dir Repository or worktree path.
## @note Each half is one-shot. Reset already flushed is not repeated
##       when a later patch batch flushes. A new PATCH queue clears only
##       the patch flag.
function(_bm_git_flush_repo _git_repo_dir)
	_bm_git_flush_resets("${_git_repo_dir}")
	_bm_git_flush_patches("${_git_repo_dir}")
endfunction()

## @brief Flush every git root that queued a reset or patch.
## @note Called from `_bm_materialize_finalize` *before* nested
##       cmake/meson so eager configure sees the patched tree.
function(_bm_git_flush_all)
	_bm_log_message(GIT LOWLEVEL "Entering _bm_git_flush_all")
	get_property(_roots GLOBAL PROPERTY BUILDMASTER_GIT_FLUSH_ROOTS)
	if(_roots)
		list(REMOVE_DUPLICATES _roots)
		foreach(_root IN LISTS _roots)
			_bm_git_flush_repo("${_root}")
		endforeach()
	endif()
	_bm_log_message(GIT LOWLEVEL "Exiting _bm_git_flush_all")
endfunction()

## @brief git reset --hard + clean -fd at parent configure.
## @param[in] _component_id Component identifier.
## @param[in] _title        Human-readable title (script filename).
## @param[in] _git_repo_dir Repository working tree.
## @note Generates the script, queues it, and flushes this root immediately:
##       resets first, then any patches already queued. That is the
##       git-sandbox / git-reset-patch contract. A later PATCH queue does
##       not re-run this reset.
## @note Does **not** write the post-install reset marker. That is PATCH-only.
## @note `_git_repo_dir` must be the component work tree
##       (`_bm_git_require_component_root`).
function(_bm_tools_git_reset _component_id _title _git_repo_dir)
	_bm_log_message(GIT LOWLEVEL "Entering _bm_tools_git_reset")
	_bm_git_require_component_root("${_git_repo_dir}")
	set(GIT_REPO "${_git_repo_dir}")
	_bm_path_sanitize(_safe "${_component_id}_${_title}")
	set(_GIT_RESET_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_reset_${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/templates/reset.cmake.in"
		"${_GIT_RESET_FILE}"
		@ONLY
	)
	_bm_git_toplevel(_root "${_git_repo_dir}")
	get_property(_resets GLOBAL PROPERTY BUILDMASTER_GIT_RESET_SCRIPTS_${_root})
	list(APPEND _resets "${_GIT_RESET_FILE}")
	list(REMOVE_DUPLICATES _resets)
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_RESET_SCRIPTS_${_root} "${_resets}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_GIT_FLUSH_ROOTS "${_root}")
	set_property(GLOBAL PROPERTY BUILDMASTER_GIT_RESET_FLUSHED_${_root} FALSE)
	_bm_git_register_op("${_component_id}" "${_git_repo_dir}")
	_bm_git_flush_repo("${_git_repo_dir}")
	_bm_log_message(GIT DEBUG "Reset git repo for ${_component_id}")
	_bm_log_message(GIT LOWLEVEL "Exiting _bm_tools_git_reset")
endfunction()
