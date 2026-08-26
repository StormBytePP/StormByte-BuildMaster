buildmaster_toolchain_export(BUILDMASTER_TOOLS_GIT_SRCDIR "${BUILDMASTER_TOOLS_GIT_SRCDIR}")
buildmaster_toolchain_export(BUILDMASTER_SCRIPTS_GIT_DIR "${BUILDMASTER_SCRIPTS_GIT_DIR}")
buildmaster_toolchain_export_raw("set(ENV_GIT_COMMAND ${ENV_GIT_COMMAND})")
buildmaster_toolchain_export_raw("set(ENV_GIT_SILENT_COMMAND ${ENV_GIT_SILENT_COMMAND})")