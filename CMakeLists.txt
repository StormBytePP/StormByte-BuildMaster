# -----------------------------------------------------------------------------
# Version
# -----------------------------------------------------------------------------
set(BUILDMASTER_VERSION "1.0.1-9999")
set(BUILDMASTER_VERSION "${BUILDMASTER_VERSION}" PARENT_SCOPE)

message(STATUS "Bootstrapping StormByte-BuildMaster ${BUILDMASTER_VERSION} (https://github.com/StormBytePP/StormByte-BuildMaster)")

# -----------------------------------------------------------------------------
# 1. Core directory variables
#    Sets BUILDMASTER_SRCDIR, BUILDMASTER_BINDIR, BUILDMASTER_SCRIPTSDIR,
#    BUILDMASTER_DOWNLOADSDIR, toolchain file, install dirs, etc.
#    BUILDMASTER_CONFIGURED is still FALSE after this step.
# -----------------------------------------------------------------------------
include(init_vars.cmake)

# -----------------------------------------------------------------------------
# 2. Helper functions (utilities + module helpers)
#    Must come before add_subdirectory(tools) because tools/extra/pkgconf
#    calls ensure_build_dir() during its init_vars.
#
#    Module helpers (cmake/git/meson/file/…) only *reference* the *_SRCDIR
#    variables when their functions are later invoked, so it is safe to
#    include them here. The actual *_SRCDIR values are set in step 4.
# -----------------------------------------------------------------------------
include(helpers.cmake)

# -----------------------------------------------------------------------------
# 3. Environment runners
#    Creates platform-specific runner scripts and related variables.
#    prepare_command() is already available from step 2.
# -----------------------------------------------------------------------------
add_subdirectory(env)
include(env/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 4. Tools (cmake, git, meson, ninja, extra, file, …)
#    Each tool’s init_vars.cmake sets its own *_SRCDIR / *_SCRIPTS_*DIR
#    (guarded by if(NOT BUILDMASTER_CONFIGURED)).
#    After this block all BUILDMASTER_TOOLS_*_SRCDIR variables exist and
#    are propagated (tools/propagate_vars.cmake must include file/).
# -----------------------------------------------------------------------------
add_subdirectory(tools)
include(tools/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 5. Component helpers
#    Depends on the tools already being initialised.
# -----------------------------------------------------------------------------
add_subdirectory(component)
include(component/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 6. Final propagation to the parent scope
#    Also sets BUILDMASTER_CONFIGURED = TRUE so nested BuildMaster instances
#    skip re-initialisation and do not overwrite parent paths.
# -----------------------------------------------------------------------------
include(propagate_vars.cmake)