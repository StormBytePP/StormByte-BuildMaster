cmake_minimum_required(VERSION 3.20)
project(BuildMasterHarness LANGUAGES C)

include(GNUInstallDirs)

add_subdirectory(
	"${CMAKE_CURRENT_SOURCE_DIR}/../.."
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster_src"
)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../helpers.cmake")

set(BM_TEST_EXPECTED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../expected")
set(BM_TEST_FIXTURES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

get_filename_component(BM_TEST_REPO_ROOT
	"${CMAKE_CURRENT_SOURCE_DIR}/../.."
	ABSOLUTE
)

# All synthetic components + recursive chains
add_subdirectory("${BM_TEST_FIXTURES_DIR}")

# ---------------------------------------------------------------------------
# Contract checks
# ---------------------------------------------------------------------------

include("${CMAKE_CURRENT_SOURCE_DIR}/check_api.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_propagation.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_dependant_edges.cmake")

add_custom_target(run_buildmaster_checks
	COMMAND ${CMAKE_COMMAND} -E echo "BuildMaster harness checks finished"
	VERBATIM
)

# ---------------------------------------------------------------------------
# Smoke
# ---------------------------------------------------------------------------

add_custom_target(run_buildmaster_smoke
	DEPENDS
		base_install dep_install sdk-headers_install sdkloader_install
		nest-cmake_install nest-meson_install
		recursion_cmake_link_test recursion_meson_link_test
	COMMAND ${CMAKE_COMMAND}
		-DBUILDMASTER_INSTALL_DIR=${BUILDMASTER_INSTALL_DIR}
		-DBM_TEST_EXPECTED_DIR=${BM_TEST_EXPECTED_DIR}
		-DBM_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
		-DBM_INSTALL_INCLUDEDIR=${CMAKE_INSTALL_INCLUDEDIR}
		-P "${CMAKE_CURRENT_SOURCE_DIR}/check_smoke_artifacts.cmake"
	VERBATIM
)
