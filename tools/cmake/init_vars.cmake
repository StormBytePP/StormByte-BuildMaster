if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_TOOLS_CMAKE_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	set(BUILDMASTER_SCRIPTS_CMAKEDIR "${BUILDMASTER_SCRIPTSDIR}/cmake")
	file(MAKE_DIRECTORY "${BUILDMASTER_SCRIPTS_CMAKEDIR}")
	get_filename_component(CMAKE_EXECUTABLE "${CMAKE_COMMAND}" NAME)
	set(_env_cmake_list "${ENV_RUNNER} ${CMAKE_EXECUTABLE}")
	set(_env_cmake_silent_list "${ENV_RUNNER_SILENT} ${CMAKE_EXECUTABLE}")
	prepare_command(ENV_CMAKE_COMMAND "${_env_cmake_list}")
	prepare_command(ENV_CMAKE_SILENT_COMMAND "${_env_cmake_silent_list}")

	# Update out part of the toolchain file
	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()