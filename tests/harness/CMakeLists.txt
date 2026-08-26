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

# ---------------------------------------------------------------------------
# Synthetic components
# Component id ≠ imported subcomponent name (avoids target clashes)
# ---------------------------------------------------------------------------

ensure_build_dir(BASE_BUILD_DIR "base")
create_cmake_component(
	BASE_FILE
	base
	"Harness base library"
	"${BM_TEST_FIXTURES_DIR}/lib_base"
	"${BASE_BUILD_DIR}"
	""
	static
	"baselib"
)
include("${BASE_FILE}")

ensure_build_dir(DEP_BUILD_DIR "dep")
create_cmake_dependant_component(
	DEP_FILE
	dep
	"Harness dependant library"
	"${BM_TEST_FIXTURES_DIR}/lib_dep"
	"${DEP_BUILD_DIR}"
	""
	static
	"deplib"
	"base_install"
)
include("${DEP_FILE}")

ensure_build_dir(HEADERS_BUILD_DIR "sdk-headers")
create_cmake_headers_component(
	HEADERS_FILE
	sdk-headers
	"Harness SDK headers"
	"${BM_TEST_FIXTURES_DIR}/headers_only"
	"${HEADERS_BUILD_DIR}"
	""
)
include("${HEADERS_FILE}")

ensure_build_dir(LOADER_BUILD_DIR "sdkloader")
create_cmake_dependant_component(
	LOADER_FILE
	sdkloader
	"Harness SDK loader"
	"${BM_TEST_FIXTURES_DIR}/lib_loader"
	"${LOADER_BUILD_DIR}"
	""
	static
	"loaderlib"
	"sdk-headers_install"
)
include("${LOADER_FILE}")

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
	DEPENDS base_install dep_install sdk-headers_install sdkloader_install
	COMMAND ${CMAKE_COMMAND}
		-DBUILDMASTER_INSTALL_DIR=${BUILDMASTER_INSTALL_DIR}
		-DBM_TEST_EXPECTED_DIR=${BM_TEST_EXPECTED_DIR}
		-DBM_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
		-DBM_INSTALL_INCLUDEDIR=${CMAKE_INSTALL_INCLUDEDIR}
		-P "${CMAKE_CURRENT_SOURCE_DIR}/check_smoke_artifacts.cmake"
	VERBATIM
)
