cmake_minimum_required(VERSION 3.20)
project(BuildMasterSelfTests LANGUAGES NONE)

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release)
endif()

add_custom_target(run_buildmaster_harness
	COMMAND ${CMAKE_COMMAND}
		-S "${CMAKE_CURRENT_SOURCE_DIR}/harness"
		-B "${CMAKE_CURRENT_BINARY_DIR}/harness"
		-G "${CMAKE_GENERATOR}"
		-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
	COMMAND ${CMAKE_COMMAND}
		--build "${CMAKE_CURRENT_BINARY_DIR}/harness"
		--target run_buildmaster_smoke
	COMMENT "Independent harness configure + smoke"
	VERBATIM
)

add_custom_target(run_buildmaster_consumer
	COMMAND ${CMAKE_COMMAND}
		-S "${CMAKE_CURRENT_SOURCE_DIR}/consumer"
		-B "${CMAKE_CURRENT_BINARY_DIR}/consumer"
		-G "${CMAKE_GENERATOR}"
		-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
	COMMAND ${CMAKE_COMMAND}
		--build "${CMAKE_CURRENT_BINARY_DIR}/consumer"
		--target consumer_host
	COMMENT "Independent consumer configure + build"
	VERBATIM
)

add_dependencies(run_buildmaster_consumer run_buildmaster_harness)

add_custom_target(run_buildmaster_tests)
add_dependencies(run_buildmaster_tests
	run_buildmaster_consumer
	run_buildmaster_harness
)
