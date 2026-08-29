# Own throwaway repo. Reset must run before patch on every configure.

set(_GRP "${CMAKE_CURRENT_BINARY_DIR}/repo")
if(NOT EXISTS "${_GRP}/.git")
    file(MAKE_DIRECTORY "${_GRP}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" init
        WORKING_DIRECTORY "${_GRP}"
        RESULT_VARIABLE _rc
    )
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "git-reset-patch: git init failed")
    endif()
    file(WRITE "${_GRP}/README" "clean\n")
    execute_process(COMMAND "${GIT_EXECUTABLE}" add README WORKING_DIRECTORY "${_GRP}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" -c user.email=bm@test -c user.name=BM
            commit -m "seed"
        WORKING_DIRECTORY "${_GRP}"
    )
endif()

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/add_marker.patch"
"diff --git a/README b/README
index 1111111..2222222 100644
--- a/README
+++ b/README
@@ -1 +1,2 @@
 clean
+patched
")

# Patch first in source order; flush must still reset then apply.
buildmaster_git_patch(
    grp
    "harness reset-patch apply"
    "${_GRP}"
    "${CMAKE_CURRENT_BINARY_DIR}/add_marker.patch"
)
buildmaster_git_reset(
    grp
    "harness reset-patch reset"
    "${_GRP}"
)

file(READ "${_GRP}/README" _readme)
if(NOT _readme MATCHES "patched")
    message(FATAL_ERROR
        "git-reset-patch: README was not patched after flush:\n${_readme}")
endif()
