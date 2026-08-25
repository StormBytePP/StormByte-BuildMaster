if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_TOOLCHAIN_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	set(BUILDMASTER_TOOLCHAIN_PROFILES_DIR "${BUILDMASTER_TOOLCHAIN_SRCDIR}/profiles")

	# Canonical toolchain names (component TOOLCHAIN=… must match one of these)
	set(BUILDMASTER_KNOWN_TOOLCHAINS gcc clang clang-cl msvc)

	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()
