# RaceA then RaceB. Each src declares the same RaceMid (which declares
# RaceBase). No parent buildmaster_depend and no hoist: the second
# configure skips Mid because links/RaceMid.cmake already exists.
# Skip must still wait (RaceB_build → RaceA_install) and still link Base.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

include(GNUInstallDirs)

buildmaster_component(
	RaceA
	"Harness race winner"
	"${CMAKE_CURRENT_SOURCE_DIR}/a/src"
	""
	shared
	"RaceA"
)

buildmaster_component(
	RaceB
	"Harness race skipper"
	"${CMAKE_CURRENT_SOURCE_DIR}/b/src"
	""
	shared
	"RaceB"
)

set(_bm_pref_lib "${BUILDMASTER_INSTALL_LIBDIR}")
set(_bm_pref_bin "${BUILDMASTER_INSTALL_DIR}/bin")
if("${_bm_pref_lib}" STREQUAL "")
	set(_bm_pref_lib "${BUILDMASTER_INSTALL_DIR}/lib")
endif()

add_executable(links_race_test
	"${CMAKE_CURRENT_SOURCE_DIR}/links_race_test.c"
)
target_include_directories(links_race_test PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(links_race_test PRIVATE RaceA RaceB)
set_target_properties(links_race_test PROPERTIES
	BUILD_RPATH "${_bm_pref_lib}"
	INSTALL_RPATH "${_bm_pref_lib}"
)
if(NOT WIN32 AND NOT APPLE)
	target_link_options(links_race_test PRIVATE
		"LINKER:--no-allow-shlib-undefined"
	)
elseif(APPLE)
	target_link_options(links_race_test PRIVATE "LINKER:-undefined,error")
endif()
add_dependencies(links_race_test RaceA_install RaceB_install)

if(WIN32)
	add_custom_target(links_race_test_run
		COMMAND ${CMAKE_COMMAND} -E env
			"PATH=${_bm_pref_bin};${_bm_pref_lib};$ENV{PATH}"
			$<TARGET_FILE:links_race_test>
		DEPENDS links_race_test
		COMMENT "[BuildMaster/Core     ]: run links_race_test (Win PATH)"
	)
else()
	add_custom_target(links_race_test_run
		COMMAND ${CMAKE_COMMAND} -E env
			"DYLD_LIBRARY_PATH=${_bm_pref_lib}:$ENV{DYLD_LIBRARY_PATH}"
			"LD_LIBRARY_PATH=${_bm_pref_lib}:$ENV{LD_LIBRARY_PATH}"
			$<TARGET_FILE:links_race_test>
		DEPENDS links_race_test
		COMMENT "[BuildMaster/Core     ]: run links_race_test"
	)
endif()
