# =============================================================================
# tools/extra/pkgconfig/init_vars.cmake — paths only
# =============================================================================

if(NOT BUILDMASTER_TOOLS_PKGCONF_SRCDIR)
	set(BUILDMASTER_TOOLS_PKGCONF_SRCDIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL
		"tools/extra/pkgconfig source dir")
endif()

set(PKG_CONFIG_WORKING FALSE)
if(NOT DEFINED PKG_CONFIG)
	set(PKG_CONFIG "")
endif()
if(NOT DEFINED PKG_CONFIG_PATH OR PKG_CONFIG_PATH STREQUAL "")
	set(PKG_CONFIG_PATH "${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig")
endif()
