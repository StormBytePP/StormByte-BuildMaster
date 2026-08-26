buildmaster_toolchain_export(BUILDMASTER_TOOLCHAIN_SRCDIR "${BUILDMASTER_TOOLCHAIN_SRCDIR}")
buildmaster_toolchain_export(BUILDMASTER_TOOLCHAIN_PROFILES_DIR "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}")
buildmaster_toolchain_export(BUILDMASTER_KNOWN_TOOLCHAINS "${BUILDMASTER_KNOWN_TOOLCHAINS}")

# Native files are exported from buildmaster_write_meson_native_file when
# generated (after this file runs on first include). Re-include is not required:
# each write calls buildmaster_toolchain_export for its variable.