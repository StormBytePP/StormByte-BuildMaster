# Non-destructive git ops in a local clone under the build tree (never the job worktree).

set(_sandbox "${CMAKE_CURRENT_BINARY_DIR}/repo")
set(_src_repo "${BM_TEST_REPO_ROOT}")

if(NOT EXISTS "${_src_repo}/.git")
	message(FATAL_ERROR "git-sandbox: BM_TEST_REPO_ROOT is not a git repo: ${_src_repo}")
endif()

if(NOT GIT_EXECUTABLE)
	message(FATAL_ERROR "git-sandbox: GIT_EXECUTABLE not set")
endif()

if(NOT EXISTS "${_sandbox}/.git")
	execute_process(
		COMMAND ${GIT_EXECUTABLE} clone --local --no-hardlinks
			"${_src_repo}" "${_sandbox}"
		RESULT_VARIABLE _clone_rc
		ERROR_VARIABLE _clone_err
	)
	if(NOT _clone_rc EQUAL 0)
		message(FATAL_ERROR "git-sandbox: clone failed: ${_clone_err}")
	endif()
endif()

# --- reset ---
file(WRITE "${_sandbox}/.bm_harness_dirty" "dirty\n")
create_git_reset_file(
	git-sandbox
	"Harness git reset"
	"${_sandbox}"
)
if(EXISTS "${_sandbox}/.bm_harness_dirty")
	message(FATAL_ERROR "git-sandbox: create_git_reset_file did not clean dirty file")
endif()

# --- patch (generate a valid unified diff with git, then re-apply via BM) ---
file(WRITE "${_sandbox}/.bm_harness_patched" "patched-by-buildmaster-harness\n")
execute_process(
	COMMAND ${GIT_EXECUTABLE} -C "${_sandbox}" add -A -- ".bm_harness_patched"
	RESULT_VARIABLE _add_rc
)
if(NOT _add_rc EQUAL 0)
	message(FATAL_ERROR "git-sandbox: git add failed")
endif()
set(_patch "${CMAKE_CURRENT_BINARY_DIR}/add_marker.patch")
execute_process(
	COMMAND ${GIT_EXECUTABLE} -C "${_sandbox}" diff --cached -- ".bm_harness_patched"
	OUTPUT_FILE "${_patch}"
	RESULT_VARIABLE _diff_rc
)
if(NOT _diff_rc EQUAL 0)
	message(FATAL_ERROR "git-sandbox: git diff --cached failed")
endif()
execute_process(
	COMMAND ${GIT_EXECUTABLE} -C "${_sandbox}" reset --hard
	RESULT_VARIABLE _rh_rc
)
if(NOT _rh_rc EQUAL 0)
	message(FATAL_ERROR "git-sandbox: git reset --hard before patch apply failed")
endif()
if(EXISTS "${_sandbox}/.bm_harness_patched")
	message(FATAL_ERROR "git-sandbox: expected clean tree before create_git_patch_file")
endif()

create_git_patch_file(
	git-sandbox
	"Harness patch"
	"${_sandbox}"
	"${_patch}"
)
if(NOT EXISTS "${_sandbox}/.bm_harness_patched")
	message(FATAL_ERROR "git-sandbox: patch did not create .bm_harness_patched")
endif()

# --- post-install marker ---
buildmaster_git_post_install_marker_for_srcdir(_marker "${_sandbox}")
if(_marker STREQUAL "" OR NOT EXISTS "${_marker}")
	message(FATAL_ERROR "git-sandbox: missing post-install reset marker")
endif()

# --- fetch (local origin from clone) ---
create_git_fetch(
	git-sandbox
	"Harness fetch"
	"${_sandbox}"
)

message(STATUS "BuildMaster git-sandbox: OK")