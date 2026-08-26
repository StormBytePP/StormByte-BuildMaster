# Synthetic components for the BuildMaster harness.
# One subdirectory per feature. recursive/ stays as cmake|meson.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../.."
		ABSOLUTE
	)
endif()

# ---------------------------------------------------------------------------
# Flat graph (base → dep, headers → loader)
# ---------------------------------------------------------------------------
add_subdirectory(base)
add_subdirectory(dep)
add_subdirectory(sdk-headers)
add_subdirectory(sdkloader)

# ---------------------------------------------------------------------------
# Declaration order must not matter (dependency + dependent before prerequisite)
# ---------------------------------------------------------------------------
add_subdirectory(order-independent)

# ---------------------------------------------------------------------------
# Install archive rename (Meson zs.* → produced z.*)
# ---------------------------------------------------------------------------
add_subdirectory(rename)

# ---------------------------------------------------------------------------
# Recursive nested BuildMaster
# ---------------------------------------------------------------------------
add_subdirectory(recursive/cmake)
add_subdirectory(recursive/meson)
