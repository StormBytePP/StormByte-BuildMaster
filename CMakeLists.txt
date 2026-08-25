# -----------------------------------------------------------------------------
# Version
# -----------------------------------------------------------------------------
set(BUILDMASTER_VERSION "1.0.9999")
set(BUILDMASTER_VERSION "${BUILDMASTER_VERSION}" PARENT_SCOPE)

message(STATUS "Bootstrapping StormByte-BuildMaster ${BUILDMASTER_VERSION} (https://github.com/StormBytePP/StormByte-BuildMaster)")

# -----------------------------------------------------------------------------
# 1. Core directory variables
# -----------------------------------------------------------------------------
include(init_vars.cmake)

# -----------------------------------------------------------------------------
# 2. Helper functions (utilities + module helpers)
# -----------------------------------------------------------------------------
include(helpers.cmake)

# -----------------------------------------------------------------------------
# 3. Toolchain profiles (validate / resolve; used by env, tools, component)
# -----------------------------------------------------------------------------
add_subdirectory(toolchain)
include(toolchain/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 4. Environment runners
# -----------------------------------------------------------------------------
add_subdirectory(env)
include(env/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 5. Tools (cmake, git, meson, ninja, extra, file, …)
# -----------------------------------------------------------------------------
add_subdirectory(tools)
include(tools/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 6. Component helpers
# -----------------------------------------------------------------------------
add_subdirectory(component)
include(component/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 7. Final propagation to the parent scope
# -----------------------------------------------------------------------------
include(propagate_vars.cmake)