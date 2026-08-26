# -----------------------------------------------------------------------------
# Version
# -----------------------------------------------------------------------------
set(BUILDMASTER_VERSION "1.0.9999")
set(BUILDMASTER_VERSION "${BUILDMASTER_VERSION}" PARENT_SCOPE)

message(STATUS "Bootstrapping StormByte-BuildMaster ${BUILDMASTER_VERSION} (https://github.com/StormBytePP/StormByte-BuildMaster)")

# -----------------------------------------------------------------------------
# 1. Core directory variables (no toolchain dump yet)
# -----------------------------------------------------------------------------
include(init_vars.cmake)

# -----------------------------------------------------------------------------
# 2. Helper functions (utilities + module helpers; loads toolchain export API)
# -----------------------------------------------------------------------------
include(helpers.cmake)

# -----------------------------------------------------------------------------
# 3. Toolchain registry: reset, base exports, then modules append via export*
# -----------------------------------------------------------------------------
buildmaster_toolchain_reset()
include("${BUILDMASTER_SRCDIR}/update_toolchain.cmake")

# -----------------------------------------------------------------------------
# 4. Toolchain profiles (validate / resolve; used by env, tools, component)
# -----------------------------------------------------------------------------
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
add_subdirectory(tools)
include(tools/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 7. Component helpers
# -----------------------------------------------------------------------------
add_subdirectory(component)
include(component/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 8. Materialize parent toolchain.cmake from the registry
# -----------------------------------------------------------------------------
buildmaster_toolchain_write("${BUILDMASTER_TOOLCHAIN_FILE}")

# -----------------------------------------------------------------------------
# 9. Final propagation to the parent scope
# -----------------------------------------------------------------------------
include(propagate_vars.cmake)
