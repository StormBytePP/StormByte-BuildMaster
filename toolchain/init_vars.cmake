if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_TOOLCHAIN_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	set(BUILDMASTER_TOOLCHAIN_PROFILES_DIR "${BUILDMASTER_TOOLCHAIN_SRCDIR}/profiles")

	# Canonical toolchain names (component TOOLCHAIN=… must match one of these)
	set(BUILDMASTER_KNOWN_TOOLCHAINS gcc clang clang-cl msvc)

	# Parent GNU rescan recipe. Platform files may already have set these
	# at project(). Do not invent a recipe here — `_bm_tc_apply_parent_link_group`
	# (CMakeLists, after helpers) wraps whatever CMake provided. Empty
	# means "not wrapped yet".
	if(NOT DEFINED CMAKE_C_LINK_EXECUTABLE)
		set(CMAKE_C_LINK_EXECUTABLE "")
	endif()
	if(NOT DEFINED CMAKE_CXX_LINK_EXECUTABLE)
		set(CMAKE_CXX_LINK_EXECUTABLE "")
	endif()

	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()
