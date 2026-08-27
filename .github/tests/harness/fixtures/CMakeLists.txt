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
# Declaration order must not matter
# ---------------------------------------------------------------------------
add_subdirectory(order-independent)

# ---------------------------------------------------------------------------
# Custom prerequisite / file / git / link
# ---------------------------------------------------------------------------
add_subdirectory(prerequisite)
add_subdirectory(file-decompress)
add_subdirectory(file-to-component)
add_subdirectory(git-sandbox)
add_subdirectory(link-component)

# ---------------------------------------------------------------------------
# Install archive rename (Meson zs.* → produced z.*)
# ---------------------------------------------------------------------------
add_subdirectory(rename)

# ---------------------------------------------------------------------------
# BUILDONLY (build + RENAME in BUILDDIR; nothing in install prefix)
# ---------------------------------------------------------------------------
add_subdirectory(buildonly)

# ---------------------------------------------------------------------------
# BUILDONLY phases + component_repack → prefix merge
# ---------------------------------------------------------------------------
add_subdirectory(repack)

# ---------------------------------------------------------------------------
# Recursive nested BuildMaster
# ---------------------------------------------------------------------------
add_subdirectory(recursive/cmake)
add_subdirectory(recursive/meson)
