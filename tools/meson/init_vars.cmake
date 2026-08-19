if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_TOOLS_MESON_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	set(BUILDMASTER_SCRIPTS_MESON_DIR "${BUILDMASTER_SCRIPTSDIR}/meson")
	find_program(MESON_EXECUTABLE meson QUIET)
	if(NOT MESON_EXECUTABLE)
		message(FATAL_ERROR "Meson executable not found: please install Meson or ensure it's on PATH.")
	endif()
	get_filename_component(MESON_EXECUTABLE "${MESON_EXECUTABLE}" NAME)
	set(_env_meson_list ${ENV_RUNNER} ${MESON_EXECUTABLE})
	set(_env_meson_list_silent ${ENV_RUNNER_SILENT} ${MESON_EXECUTABLE})
	prepare_command(ENV_MESON_COMMAND "${_env_meson_list}")
	prepare_command(ENV_MESON_SILENT_COMMAND "${_env_meson_list_silent}")

	# In debug mode, ENV_MESON_SILENT is the same as ENV_MESON
	if(BUILDMASTER_DEBUG)
		set(ENV_MESON_SILENT_COMMAND "${ENV_MESON_COMMAND}")
	endif()

	# Update out part of the toolchain file
	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()