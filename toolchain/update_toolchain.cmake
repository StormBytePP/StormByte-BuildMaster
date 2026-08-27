buildmaster_toolchain_export(BUILDMASTER_TOOLCHAIN_SRCDIR "${BUILDMASTER_TOOLCHAIN_SRCDIR}")
buildmaster_toolchain_export(BUILDMASTER_TOOLCHAIN_PROFILES_DIR "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}")

# Semicolon list in the dump. A raw "${LIST}" can become newlines in the
# nested toolchain file and then list(FIND) misses "gcc".
string(REPLACE "\n" ";" _bm_known_export "${BUILDMASTER_KNOWN_TOOLCHAINS}")
string(REPLACE "\r" "" _bm_known_export "${_bm_known_export}")
string(REPLACE " " ";" _bm_known_export "${_bm_known_export}")
list(REMOVE_DUPLICATES _bm_known_export)
list(JOIN _bm_known_export ";" _bm_known_export)
buildmaster_toolchain_export(BUILDMASTER_KNOWN_TOOLCHAINS "${_bm_known_export}")

# Native files are exported from buildmaster_write_meson_native_file when
# generated (after this file runs on first include). Re-include is not required:
# each write calls buildmaster_toolchain_export for its variable.
