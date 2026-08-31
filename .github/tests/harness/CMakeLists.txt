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

add_subdirectory("${BM_TEST_FIXTURES_DIR}")

# Materialize before contract checks.
#
# Consumers rely on cmake_language(DEFER) at the end of CMAKE_SOURCE_DIR and
# never call finalize. This harness is different: check_api.cmake,
# check_dependant_edges.cmake, and friends run during *this* configure, after
# fixtures are declared but before this CMakeLists finishes. Without an
# explicit materialize, those checks would see no targets or dependency edges.
# _bm_materialize_finalize is internal and idempotent; the deferred
# callback later is a no-op.
_bm_materialize_finalize()

include("${CMAKE_CURRENT_SOURCE_DIR}/check_tc_prefix.cmake")

# ---------------------------------------------------------------------------
# Contract checks
# ---------------------------------------------------------------------------

include("${CMAKE_CURRENT_SOURCE_DIR}/check_api.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_propagation.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_dependant_edges.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_linkflags.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_hooks.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_link_raw.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_private_headers.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_groups.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/check_files_hash.cmake")

add_custom_target(run_buildmaster_checks
	COMMENT "[BuildMaster/Core     ]: harness contract checks"
	VERBATIM
)

# Isolated consumer project (Logger pattern: lib/ first, then thirdparty/BM).
# Own CMAKE_SOURCE_DIR on purpose. Host binary lives under lib/.
set(_BM_CONSUMER_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../consumer")
set(_BM_CONSUMER_BIN "${CMAKE_CURRENT_BINARY_DIR}/consumer_nested")
set(_BM_CONSUMER_EXE "${_BM_CONSUMER_BIN}/lib/consumer_host${CMAKE_EXECUTABLE_SUFFIX}")

add_custom_target(run_buildmaster_consumer
	COMMAND ${CMAKE_COMMAND}
		-S "${_BM_CONSUMER_SRC}"
		-B "${_BM_CONSUMER_BIN}"
		-G "${CMAKE_GENERATOR}"
		-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
	COMMAND ${CMAKE_COMMAND} --build "${_BM_CONSUMER_BIN}" --target consumer_host
	COMMAND "${_BM_CONSUMER_EXE}"
	COMMENT "[BuildMaster/Core     ]: consumer add_subdirectory + DEFER finalize"
	VERBATIM
)

# ---------------------------------------------------------------------------
# Smoke
# ---------------------------------------------------------------------------

set(_BM_SMOKE_UNIX "")
if(NOT WIN32)
	set(_BM_SMOKE_UNIX linkflags_unix_test_run)
endif()

add_custom_target(run_buildmaster_smoke
	COMMAND ${CMAKE_COMMAND}
		-DBUILDMASTER_INSTALL_DIR=${BUILDMASTER_INSTALL_DIR}
		-DBM_TEST_EXPECTED_DIR=${CMAKE_CURRENT_SOURCE_DIR}/../expected
		-DBM_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
		-DBM_INSTALL_INCLUDEDIR=${CMAKE_INSTALL_INCLUDEDIR}
		-P ${CMAKE_CURRENT_SOURCE_DIR}/check_smoke_artifacts.cmake
	COMMENT "[BuildMaster/Core     ]: smoke — install stages + artifact contract"
	DEPENDS
		# Consumer (own source dir / DEFER)
		run_buildmaster_consumer
		# Core / flat
		base_install dep_install first_install link-a_install link-b_install
		payload-lib_install sdk-headers_install
		sdkloader_install second_install
		# Meta
		leaf-a_install leaf-b_install meta-inner_install meta-out_install
		meta-plugins_install meta-tc_install meta_link_test_run
		mtc-inherit_install mtc-pinned_install
		# Groups (CMake + Meson leaves)
		grp-opus_install grp-speex_install grp-maudio_install
		grp-vmaf_install grp-ssim_install grp-mfilter_install
		grp-orphan_install
		# Order / link tests
		link_component_test order_independent_link_test
		# LINKFLAGS
		lf-os_install lf-unix_install
		linkflags_os_test_run
		# NOINSTALL
		noinstall-lib_install
		${_BM_SMOKE_UNIX}
		# Pkg-config helper
		pc-dep_install pc-lib_install pc_check_run
		# Recursive
		nest-cmake_install nest-meson_install
		recursion_cmake_link_test recursion_meson_link_test
		# Rename
		rename-variant_install rename_variant_link_test
		# Repack (NOINSTALL phases + REPACK meta)
		repack-a_install repack-b_install mergedlib_install
		repack_link_test
		# Slow configure
		slow-configure_install
		# TOOLCHAIN
		nest-tc_install
		tc-prefix_install
		# WHOLE
		out-lib_install plain-lib_install whole-lib_install
		whole_link_test_nowhole_run whole_link_test_run
		# harness-expand
		hook-a_install hook-b_install
		hooks-stamp_install
		late-dst_install late-src_install
		omit-lib_install
		omit-lib_install
		be-pick_install
		dup-a_install dup-b_install
		raw-lib_install
		# PRIVATE headers consumer (compile fails if -I missing)
		priv-h_install
		priv-consumer_install
	VERBATIM
)

# ---------------------------------------------------------------------------
# harness-expand: configure-time FATAL cases
# ---------------------------------------------------------------------------
add_custom_target(run_buildmaster_negative
	COMMAND ${CMAKE_COMMAND}
		-DBM_TEST_REPO_ROOT=${BM_TEST_REPO_ROOT}
		-DBM_TEST_NEGATIVE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/../negative
		-DCMAKE_GENERATOR=${CMAKE_GENERATOR}
		-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
		-P ${CMAKE_CURRENT_SOURCE_DIR}/run_negative.cmake
	COMMENT "[BuildMaster/Core     ]: negative configure contracts"
	VERBATIM
)
add_dependencies(run_buildmaster_smoke run_buildmaster_negative)
