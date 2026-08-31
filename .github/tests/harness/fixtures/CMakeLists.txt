# Synthetic components for the BuildMaster harness.
# One subdirectory per feature. recursive/ stays as cmake|meson.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../.."
		ABSOLUTE
	)
endif()

# ---------------------------------------------------------------------------
# NOINSTALL
# ---------------------------------------------------------------------------
add_subdirectory(noinstall)

# ---------------------------------------------------------------------------
# File helpers (FILES unpack on a real component)
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
# Outline groups (banners + walk order)
# ---------------------------------------------------------------------------
add_subdirectory(groups)

# ---------------------------------------------------------------------------
# Order / link
# ---------------------------------------------------------------------------
add_subdirectory(link-component)
add_subdirectory(order-independent)

# ---------------------------------------------------------------------------
# LINKFLAGS platform groups
# ---------------------------------------------------------------------------
add_subdirectory(linkflags)

# ---------------------------------------------------------------------------
# Pkg-config helper
# ---------------------------------------------------------------------------
add_subdirectory(pc)
add_subdirectory(require-tool-pkgconfig)

# ---------------------------------------------------------------------------
# Recursive nested BuildMaster
# ---------------------------------------------------------------------------
add_subdirectory(recursive/cmake)
add_subdirectory(recursive/meson)

# ---------------------------------------------------------------------------
# ALIAS + links/ (Buffer→Logger→Base; host only links Buffer)
# static chain (existing) + SHARED host (Crypto analogue)
# ---------------------------------------------------------------------------
add_subdirectory(links-chain)
add_subdirectory(links-shared-chain)

# ---------------------------------------------------------------------------
# Install archive rename (Meson zs.* → produced z.*)
# ---------------------------------------------------------------------------
add_subdirectory(rename)

# ---------------------------------------------------------------------------
# Static archive merge
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
add_subdirectory(tc-prefix)

# ---------------------------------------------------------------------------
# WHOLE archive link
# ---------------------------------------------------------------------------
add_subdirectory(whole)

# ---------------------------------------------------------------------------
# harness-expand
# ---------------------------------------------------------------------------
add_subdirectory(hooks)
add_subdirectory(hooks-stamp)
add_subdirectory(late-link)
add_subdirectory(omit-builddir)
add_subdirectory(backend-pick)
add_subdirectory(dup-link)
add_subdirectory(link-raw)
add_subdirectory(git-reset-patch)

# ---------------------------------------------------------------------------
# PRIVATE headers (no backend) + configure -I
# ---------------------------------------------------------------------------
add_subdirectory(private-headers)
