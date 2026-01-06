## @brief Generate a CMake script that applies a set of git patches to a
##        repository.
## @param[out] _out_file Name of the variable to set in parent scope
##            with the generated CMake filename that will apply the
##            patches.
## @param[in] _component Arbitrary component name used to produce a
##            filesystem-safe filename for the generated script.
## @param[in] _git_repo_dir Path to the git repository where the
##            patches should be applied; written into the generated
##            script as `GIT_REPO`.
## @param[in] _git_patches CMake list of patch filenames (may be a
##            list variable name). The list is joined into a
##            space-separated string and exposed as `GIT_PATCHES` in the
##            generated script.
## @note Sanitizes `_component` into a safe filename fragment and
##       produces `git_patch_<sanitized>.cmake` in the bootstrap git
##       binary directory by configuring `patch.cmake.in`. Returns the
##       path to the generated file in `_out_file` (parent scope).
function(create_git_patch_file _file _component _git_repo_dir _git_paches)
	set(GIT_REPO "${_git_repo_dir}")
	list_join(GIT_PATCHES "${_git_paches}" " ")
	sanitize_for_filename(_GIT_PATCH_NAME "${_component}")
	set(_GIT_PATCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_patch_${_GIT_PATCH_NAME}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/patch.cmake.in"
		"${_GIT_PATCH_FILE}"
		@ONLY
	)
	set(${_file} "${_GIT_PATCH_FILE}" PARENT_SCOPE)
endfunction()


## @brief Generate a CMake script that resets a repository to a clean
##        state.
## @param[out] _out_file Name of the variable to set in parent scope
##            with the generated reset script filename.
## @param[in] _component Arbitrary component name used for the generated
##            filename.
## @param[in] _git_repo_dir Path to the git repository to reset (written
##            as `GIT_REPO` into the generated file).
## @note Sanitizes `_component` and creates `git_reset_<sanitized>.cmake`
##       in the bootstrap git binary dir using `reset.cmake.in` as a
##       template. Returns the path in `_out_file` (parent scope).
function(create_git_reset_file _file _component _git_repo_dir)
	set(GIT_REPO "${_git_repo_dir}")
	sanitize_for_filename(_GIT_RESET_NAME "${_component}")
	set(_GIT_RESET_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_reset_${_GIT_RESET_NAME}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/reset.cmake.in"
		"${_GIT_RESET_FILE}"
		@ONLY
	)
	set(${_file} "${_GIT_RESET_FILE}" PARENT_SCOPE)
endfunction()

## @brief Generate a CMake script that switches a repository to a
##        specific branch.
## @param[out] _out_file Name of the variable to set in parent scope
##            with the generated switch script filename.
## @param[in] _component Arbitrary component name used to produce a
##            filesystem-safe filename for the generated script.
## @param[in] _git_repo_dir Path to the git repository to switch; this
##            value is written into the generated script as `GIT_REPO`.
## @param[in] _git_branch Branch name to check out (exposed as
##            `GIT_BRANCH`).
## @note Sanitizes `_component` into a safe filename fragment and
##       produces `git_switch_<sanitized>.cmake` by configuring
##       `switch.cmake.in`. Returns the path in `_out_file` (parent
##       scope).
function(create_git_switch_branch _file _component _git_repo_dir _git_branch)
	set(GIT_REPO "${_git_repo_dir}")
	set(GIT_BRANCH "${_git_branch}")
	sanitize_for_filename(_GIT_SWITCH_NAME "${_component}")
	set(_GIT_SWITCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_switch_${_GIT_SWITCH_NAME}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/switch.cmake.in"
		"${_GIT_SWITCH_FILE}"
		@ONLY
	)
	set(${_file} "${_GIT_SWITCH_FILE}" PARENT_SCOPE)
endfunction()

## @brief Generate a CMake script that performs a `git fetch` for a
##        repository. The function does not execute git itself; it
##        produces a standalone CMake script from `fetch.cmake.in`.
## @param[out] _out_file Name of the variable to set in parent scope
##            with the generated fetch script filename.
## @param[in] _component Arbitrary component name used to produce a
##            filesystem-safe filename for the generated script.
## @param[in] _git_repo_dir Path to the git repository to fetch (written
##            as `GIT_REPO` into the generated file).
## @note Sanitizes `_component` and produces `git_fetch_<sanitized>.cmake`
##       under the bootstrap git binary directory by configuring
##       `fetch.cmake.in`. Returns the path in `_out_file` (parent
##       scope).
function(create_git_fetch _file _component _git_repo_dir)
	set(GIT_REPO "${_git_repo_dir}")
	sanitize_for_filename(_GIT_FETCH_NAME "${_component}")
	set(_GIT_FETCH_FILE "${BUILDMASTER_SCRIPTS_GIT_DIR}/git_fetch_${_GIT_FETCH_NAME}.cmake")
	configure_file(
		"${BUILDMASTER_TOOLS_GIT_SRCDIR}/fetch.cmake.in"
		"${_GIT_FETCH_FILE}"
		@ONLY
	)
	set(${_file} "${_GIT_FETCH_FILE}" PARENT_SCOPE)
endfunction()
