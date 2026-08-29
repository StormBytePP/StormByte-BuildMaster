# Synthetic components for the BuildMaster harness.
# One subdirectory per feature. recursive/ stays as cmake|meson.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../.."
		ABSOLUTE
	)
endif()

# ---------------------------------------------------------------------------
# BUILDONLY
# ---------------------------------------------------------------------------
add_subdirectory(buildonly)

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------
add_subdirectory(file-decompress)
add_subdirectory(file-to-component)

# ---------------------------------------------------------------------------
# Flat graph (base → dep, headers → loader)
# ---------------------------------------------------------------------------
add_subdirectory(base)
add_subdirectory(dep)
add_subdirectory(sdk-headers)
add_subdirectory(sdkloader)

# ---------------------------------------------------------------------------
# Git sandbox (configure-time)
# ---------------------------------------------------------------------------
add_subdirectory(git-sandbox)

# ---------------------------------------------------------------------------
# Meta collections
# ---------------------------------------------------------------------------
add_subdirectory(meta)
add_subdirectory(meta-toolchain)

# ---------------------------------------------------------------------------
# Order / link
# ---------------------------------------------------------------------------
add_subdirectory(link-component)
add_subdirectory(order-independent)
add_subdirectory(prerequisite)

# ---------------------------------------------------------------------------
# LINKFLAGS platform groups
# ---------------------------------------------------------------------------
add_subdirectory(linkflags)

# ---------------------------------------------------------------------------
# Pkg-config helper
# ---------------------------------------------------------------------------
add_subdirectory(pc)

# ---------------------------------------------------------------------------
# Recursive nested BuildMaster
# ---------------------------------------------------------------------------
add_subdirectory(recursive/cmake)
add_subdirectory(recursive/meson)

# ---------------------------------------------------------------------------
# Install archive rename (Meson zs.* → produced z.*)
# ---------------------------------------------------------------------------
add_subdirectory(rename)

# ---------------------------------------------------------------------------
# Static archive repack
# ---------------------------------------------------------------------------
add_subdirectory(repack)

# ---------------------------------------------------------------------------
# Slow configure (Ninja COMMENT timing)
# ---------------------------------------------------------------------------
add_subdirectory(slow-configure)

# ---------------------------------------------------------------------------
# TOOLCHAIN swap
# ---------------------------------------------------------------------------
add_subdirectory(toolchain)

# ---------------------------------------------------------------------------
# WHOLE archive link
# ---------------------------------------------------------------------------
add_subdirectory(whole)

# ---------------------------------------------------------------------------
# harness-expand
# ---------------------------------------------------------------------------
add_subdirectory(hooks)
add_subdirectory(late-link)
add_subdirectory(omit-builddir)
add_subdirectory(dup-link)
add_subdirectory(link-raw)
add_subdirectory(git-reset-patch)
