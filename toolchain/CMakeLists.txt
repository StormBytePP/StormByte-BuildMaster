include(init_vars.cmake)
include(helpers.cmake)
include(meson_native.cmake)

# Generate native_*.ini once compilers and SCRIPTSDIR are known. Registers
# BUILDMASTER_MESON_NATIVE_FILE* into the toolchain dump for nested projects.
buildmaster_init_meson_native_files()

include(propagate_vars.cmake)