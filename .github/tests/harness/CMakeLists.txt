cmake_minimum_required(VERSION 3.20)
project(BuildMasterHarness LANGUAGES C)

include(GNUInstallDirs)

# Repo root is three levels up: harness → tests → .github → <root>
add_subdirectory(
	"${CMAKE_CURRENT_SOURCE_DIR}/../../.."
	"${CMAKE_CURRENT_BINARY_DIR}/buildmaster_src"
)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../../helpers.cmake")

set(BM_TEST_EXPECTED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../expected")
set(BM_TEST_FIXTURES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

get_filename_component(BM_TEST_REPO_ROOT
	"${CMAKE_CURRENT_SOURCE_DIR}/../../.."
	ABSOLUTE
)

# All synthetic components + recursive chains (+ rename if present)
add_subdirectory("${BM_TEST_FIXTURES_DIR}")

# Materialize before contract checks.
#
# Consumers rely on cmake_language(DEFER) at the end of CMAKE_SOURCE_DIR and
# never call finalize. This harness is different: check_api.cmake,
# check_dependant_edges.cmake, and friends run during *this* configure, after
# fixtures are declared but before this CMakeLists finishes. Without an
# explicit materialize, those checks would see no targets or dependency edges.
# _buildmaster_finalize_components is internal and idempotent; the deferred
# callback later is a no-op.
_buildmaster_finalize_components()

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
	COMMAND ${CMAKE_COMMAND}
		-DBUILDMASTER_INSTALL_DIR=${BUILDMASTER_INSTALL_DIR}
		-DBM_TEST_EXPECTED_DIR=${CMAKE_CURRENT_SOURCE_DIR}/../expected
		-DBM_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
		-DBM_INSTALL_INCLUDEDIR=${CMAKE_INSTALL_INCLUDEDIR}
		-P ${CMAKE_CURRENT_SOURCE_DIR}/check_smoke_artifacts.cmake
	COMMENT "BuildMaster smoke: install stages + artifact contract"
	DEPENDS
		# BUILDONLY
		buildonly-lib_install
		# Core / flat
		base_install dep_install first_install link-a_install link-b_install
		payload-lib_install prereq-lib_install sdk-headers_install
		sdkloader_install second_install
		# Meta
		leaf-a_install leaf-b_install meta-inner_install meta-out_install
		meta-plugins_install meta_link_test_run
		# Order / link tests
		link_component_test order_independent_link_test
		# Recursive
		nest-cmake_install nest-meson_install
		recursion_cmake_link_test recursion_meson_link_test
		# Rename
		rename-variant_install rename_variant_link_test
		# Repack
		repack-a_install repack-b_install repack-merged_install
		repack_link_test
		# WHOLE
		out-lib_install plain-lib_install whole-lib_install
		whole_link_test_nowhole_run whole_link_test_run
	VERBATIM
)
