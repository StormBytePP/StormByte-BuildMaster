# =============================================================================
# tools/extra/pkgconfig/resolve.cmake — system probe or bundled build
# =============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/../../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../../../paths.cmake")

## @brief Resolve pkg-config / pkgconf. System first, bundled Meson else.
## @note Required hook for `_bm_tools_demand_extra(pkgconfig)`.
## @note `BUILDMASTER_TOOLS_PKGCONFIG_FORCE_BUNDLED=ON` skips the system
##       probe (harness only).
## @note Bundled install runs at **configure** time. The ninja binary is
##       invoked directly (`CMAKE_MAKE_PROGRAM`, else the last element of
##       `ENV_NINJA_COMMAND`). The env runner is not used here: on Windows
##       it can swallow `-C` and `ninja install` returns 0 after copying
##       docs without building `pkgconf${CMAKE_EXECUTABLE_SUFFIX}`.
## @note After `ninja install`, the prefix exe must exist. rc=0 is not
##       enough.
## @note Always sets `PKG_CONFIG_PATH` to
##       `${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig` (GNUInstallDirs: `lib` or
##       `lib64`) and calls `_bm_env_update_runner()` so the generated
##       runner exports it. On-demand tools run after the first runner
##       write; skipping the refresh leaves `update_pkgconfig_path=""`.
function(_bm_extra_pkgconfig_init)
	_bm_log_message(PKGCONF LOWLEVEL "Entering _bm_extra_pkgconfig_init")

	_bm_tools_demand_named(meson)

	set(_force_bundled FALSE)
	if(BUILDMASTER_TOOLS_PKGCONFIG_FORCE_BUNDLED)
		set(_force_bundled TRUE)
		_bm_log_message(PKGCONF STATUS
			"FORCE_BUNDLED: skipping system pkg-config probe" 3)
	endif()

	if(NOT _force_bundled)
		find_package(PkgConfig QUIET)
		if(PKG_CONFIG_FOUND)
			execute_process(
				COMMAND "${PKG_CONFIG_EXECUTABLE}" --version
				OUTPUT_VARIABLE _pkg_config_version_ignored
				RESULT_VARIABLE _pkg_config_test_result
				ERROR_VARIABLE _pkg_config_test_err_ignored
			)
			if(NOT _pkg_config_test_result EQUAL 0)
				_bm_log_message(PKGCONF WARNING
					"Testing system pkg-config failed, using bundled one instead")
			else()
				set(PKG_CONFIG_WORKING TRUE)
				set(PKG_CONFIG "${PKG_CONFIG_EXECUTABLE}")
				set(PKG_CONFIG_VERSION "${PKG_CONFIG_VERSION_STRING}")
				_bm_log_message(PKGCONF STATUS
					"Using system pkg-config version: ${PKG_CONFIG_VERSION}" 3)
			endif()
		endif()
	endif()

	if(NOT PKG_CONFIG_WORKING)
		if(NOT ENV_NINJA_COMMAND)
			_bm_log_message(PKGCONF FATAL
				"ENV_NINJA_COMMAND is empty; bootstrap ninja did not export it")
		endif()

		set(PKGCONF_SRCDIR "${BUILDMASTER_TOOLS_PKGCONF_SRCDIR}/src")
		_bm_path_component_builddir(PKGCONF_BUILD_DIR pkgconf)
		file(MAKE_DIRECTORY "${PKGCONF_BUILD_DIR}")

		if(NOT EXISTS "${PKGCONF_SRCDIR}/meson.build")
			_bm_log_message(PKGCONF FATAL
				"bundled pkgconf source missing: ${PKGCONF_SRCDIR}/meson.build")
		endif()

		set(PKGCONF_MESON_OPTIONS "-Ddefault_library=static")
		_bm_tools_meson_stages(
			PKGCONF_MESON_SETUP_FILE
			_ignored_compile_file
			_ignored_install_file
			"pkgconf"
			"pkgconf"
			"${PKGCONF_SRCDIR}"
			"${PKGCONF_BUILD_DIR}"
			"${PKGCONF_MESON_OPTIONS}"
			"static"
			"pkgconf"
			3
		)
		include("${PKGCONF_MESON_SETUP_FILE}")

		if(NOT EXISTS "${PKGCONF_BUILD_DIR}/build.ninja")
			_bm_log_message(PKGCONF FATAL
				"meson setup did not write ${PKGCONF_BUILD_DIR}/build.ninja")
		endif()

		# Configure-time extra: raw ninja, not ENV_NINJA_COMMAND (runner).
		set(_bm_ninja "")
		if(CMAKE_MAKE_PROGRAM)
			set(_bm_ninja "${CMAKE_MAKE_PROGRAM}")
		else()
			list(GET ENV_NINJA_COMMAND -1 _bm_ninja)
		endif()
		if(_bm_ninja STREQUAL "")
			_bm_log_message(PKGCONF FATAL
				"no ninja binary for bundled pkgconf (CMAKE_MAKE_PROGRAM empty and ENV_NINJA_COMMAND='${ENV_NINJA_COMMAND}')")
		endif()

		execute_process(
			COMMAND "${_bm_ninja}" -C "${PKGCONF_BUILD_DIR}" install
			RESULT_VARIABLE _pkgconf_build_result
			OUTPUT_VARIABLE _pkgconf_build_out
			ERROR_VARIABLE _pkgconf_build_err
			WORKING_DIRECTORY "${PKGCONF_BUILD_DIR}"
		)
		if(NOT _pkgconf_build_result EQUAL 0)
			_bm_log_message(PKGCONF FATAL
				"Building pkgconf failed (exit ${_pkgconf_build_result})\nbuilddir=${PKGCONF_BUILD_DIR}\nninja=${_bm_ninja}\n--- stdout ---\n${_pkgconf_build_out}\n--- stderr ---\n${_pkgconf_build_err}")
		endif()

		set(PKG_CONFIG "${BUILDMASTER_INSTALL_BINDIR}/pkgconf${CMAKE_EXECUTABLE_SUFFIX}")
		if(NOT EXISTS "${PKG_CONFIG}")
			_bm_log_message(PKGCONF FATAL
				"bundled pkgconf install did not produce ${PKG_CONFIG}\nbuilddir=${PKGCONF_BUILD_DIR}\nninja=${_bm_ninja}\n--- stdout ---\n${_pkgconf_build_out}\n--- stderr ---\n${_pkgconf_build_err}")
		endif()

		execute_process(
			COMMAND "${PKG_CONFIG}" --version
			RESULT_VARIABLE _pkgconf_test_result
			OUTPUT_VARIABLE _pkgconf_version
			ERROR_VARIABLE _pkgconf_test_err
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_STRIP_TRAILING_WHITESPACE
		)
		if(NOT _pkgconf_test_result EQUAL 0)
			_bm_log_message(PKGCONF FATAL
				"Testing pkgconf failed (exit ${_pkgconf_test_result}) exe=${PKG_CONFIG}\n${_pkgconf_test_err}")
		endif()
		set(PKG_CONFIG_WORKING TRUE)
		set(PKG_CONFIG_VERSION "${_pkgconf_version}")
		_bm_log_message(PKGCONF STATUS
			"Using bundled pkgconf version: ${PKG_CONFIG_VERSION}" 3)
	endif()

	set(PKG_CONFIG_PATH "${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig")
	_bm_env_update_runner()
	_bm_log_message(PKGCONF DEBUG
		"runner refresh PKG_CONFIG=${PKG_CONFIG} PKG_CONFIG_PATH=${PKG_CONFIG_PATH}")

	set(PKG_CONFIG "${PKG_CONFIG}" PARENT_SCOPE)
	set(PKG_CONFIG_PATH "${PKG_CONFIG_PATH}" PARENT_SCOPE)
	set(PKG_CONFIG_WORKING "${PKG_CONFIG_WORKING}" PARENT_SCOPE)
	if(PKG_CONFIG)
		set(PKG_CONFIG "${PKG_CONFIG}" CACHE FILEPATH "pkg-config executable" FORCE)
	endif()
	set(PKG_CONFIG_PATH "${PKG_CONFIG_PATH}" CACHE PATH "pkg-config search path" FORCE)

	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
	_bm_log_message(PKGCONF LOWLEVEL "Exiting _bm_extra_pkgconfig_init")
endfunction()
