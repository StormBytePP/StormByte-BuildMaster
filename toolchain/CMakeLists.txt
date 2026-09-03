include(init_vars.cmake)
include(helpers.cmake)
include(meson_native.cmake)

# Generate native_*.ini once compilers and SCRIPTSDIR are known. Registers
# BUILDMASTER_MESON_NATIVE_FILE* into the toolchain dump for nested projects.
_bm_tc_init_meson_native_files()

# Parent exe + static archives: GNU rescan. Nested bootstrap never
# reaches this CMakeLists (BUILDMASTER_CONFIGURED return in trunk).
_bm_tc_apply_parent_link_group()

include(propagate_vars.cmake)
