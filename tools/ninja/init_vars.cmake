if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_TOOLS_NINJA_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	find_program(NINJA_EXECUTABLE ninja QUIET)
	if(NOT NINJA_EXECUTABLE)
		message(FATAL_ERROR "Ninja executable not found: please install Ninja or ensure it's on PATH.")
	endif()
	get_filename_component(NINJA_EXECUTABLE "${NINJA_EXECUTABLE}" NAME)
	set(_env_ninja_list ${ENV_RUNNER} ${NINJA_EXECUTABLE} "-j${NPROC}")
	set(_env_ninja_silent_list ${ENV_RUNNER_SILENT} ${NINJA_EXECUTABLE} "-j${NPROC}")
	prepare_command(ENV_NINJA_COMMAND "${_env_ninja_list}")
	prepare_command(ENV_NINJA_SILENT_COMMAND "${_env_ninja_silent_list}")

	# In debug mode, ENV_NINJA_SILENT is the same as ENV_NINJA
	if(BUILDMASTER_DEBUG)
		set(ENV_NINJA_SILENT_COMMAND "${ENV_NINJA_COMMAND}")
	endif()

	# Update out part of the toolchain file
	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()