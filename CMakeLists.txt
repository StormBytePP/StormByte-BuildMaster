# -----------------------------------------------------------------------------
# Version
# -----------------------------------------------------------------------------
set(BUILDMASTER_VERSION "1.0.1")
set(BUILDMASTER_VERSION "${BUILDMASTER_VERSION}" PARENT_SCOPE)

# -----------------------------------------------------------------------------
# 1. Core directory variables
# -----------------------------------------------------------------------------
# When the host project was configured with -DCMAKE_TOOLCHAIN_FILE pointing at
# an existing BuildMaster toolchain.cmake, that file already set
# BUILDMASTER_CONFIGURED and the full BUILDMASTER_* / ENV_* snapshot. init_vars
# then skips path creation (paths come from the toolchain only).
include(init_vars.cmake)

# -----------------------------------------------------------------------------
# Nested bootstrap guard
# -----------------------------------------------------------------------------
# Nested projects (e.g. Buffer → Logger → Base) load the *same* shared
# BUILDMASTER_TOOLCHAIN_FILE as CMAKE_TOOLCHAIN_FILE. They then
# add_subdirectory(buildmaster). If we ran the full bootstrap again we would:
#   - buildmaster_toolchain_reset() clear the in-memory registry
#   - re-export only the root update_toolchain lines
#   - buildmaster_toolchain_write() overwrite the parent toolchain.cmake with an
#     incomplete file (missing TOOLS_CMAKE_SRCDIR, COMPONENT_SRCDIR, ENV_*, …)
# That incomplete file is what later causes:
#   File /configure.cmake.in does not exist
#   File /component_shared.cmake.in does not exist
#
# Order matters: this check runs after init_vars (so CONFIGURED from the
# toolchain is visible) and before any reset/write or add_subdirectory of
# modules. Nested hosts still need helpers.cmake so create_* APIs remain
# available; then we propagate and stop.
if(BUILDMASTER_CONFIGURED)
    # Root helpers do not pull tools/helpers.cmake; that file is normally
    # loaded by add_subdirectory(tools). Nested bootstrap skips subdirs but
    # still runs tools/propagate_vars.cmake → need the extra-tools macros.
    include(helpers.cmake)
    include("${BUILDMASTER_SRCDIR}/tools/helpers.cmake")
    include(propagate_vars.cmake)
    return()
endif()

message(STATUS "Bootstrapping StormByte-BuildMaster ${BUILDMASTER_VERSION} (https://github.com/StormBytePP/StormByte-BuildMaster)")

# -----------------------------------------------------------------------------
# 2. Helper functions (utilities + module helpers; loads toolchain export API)
# -----------------------------------------------------------------------------
include(helpers.cmake)

# -----------------------------------------------------------------------------
# 3. Toolchain registry (primary bootstrap only)
# -----------------------------------------------------------------------------
# Reset must run before any export*. Modules register lines into a global
# property; a single write at the end materializes toolchain.cmake. Never call
# reset/write from a nested bootstrap (guard above).
buildmaster_toolchain_reset()
include("${BUILDMASTER_SRCDIR}/update_toolchain.cmake")

# -----------------------------------------------------------------------------
# 4. Toolchain profiles (validate / resolve; used by env, tools, component)
# -----------------------------------------------------------------------------
# Profiles and known-toolchain list are registered into the dump via this
# module's update_toolchain.cmake (included from its init_vars while
# CONFIGURED is still false).
add_subdirectory(toolchain)
include(toolchain/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 5. Environment runners
# -----------------------------------------------------------------------------
add_subdirectory(env)
include(env/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 6. Tools (cmake, git, meson, ninja, extra, file, …)
# -----------------------------------------------------------------------------
# Each tool's init_vars registers BUILDMASTER_TOOLS_*_SRCDIR, SCRIPTS_* and
# ENV_* into the registry. These exports must happen before the final write
# or nested configures will lack template roots.
add_subdirectory(tools)
include(tools/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 7. Component helpers
# -----------------------------------------------------------------------------
add_subdirectory(component)
include(component/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 8. Materialize parent toolchain.cmake from the full registry
# -----------------------------------------------------------------------------
# Single write after every module has registered. This file is the sole source
# of truth for nested projects (CONFIGURED=TRUE path above).
buildmaster_toolchain_write("${BUILDMASTER_TOOLCHAIN_FILE}")

# -----------------------------------------------------------------------------
# 9. Final propagation to the parent scope
# -----------------------------------------------------------------------------
include(propagate_vars.cmake)