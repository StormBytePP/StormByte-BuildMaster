# TransBase ← TransMid ← TransUpper, then a deferred TransLeaf that
# only buildmaster_link()s TransUpper. Leaf calls a Base-only symbol.
# The parent must not name Mid or Base: that is the contract under test.
# Leaf configures after this process writes links/, and it skips Upper,
# so the link line comes from the file, not from a second configure.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

include(GNUInstallDirs)

buildmaster_component(
	TransUpper
	"Harness transitive upper"
	"${CMAKE_CURRENT_SOURCE_DIR}/upper/src"
	""
	shared
	"TransUpper"
)

buildmaster_component(
	TransLeaf
	"Harness transitive leaf"
	"${CMAKE_CURRENT_SOURCE_DIR}/leaf/src"
	""
	shared
	"TransLeaf"
)

# Deferred on purpose: links/TransUpper.cmake must already exist so the
# nested leaf hits "already built by" and cannot rediscover Base.
buildmaster_depend(TransLeaf TransUpper)

set(_bm_pref_lib "${BUILDMASTER_INSTALL_LIBDIR}")
set(_bm_pref_bin "${BUILDMASTER_INSTALL_DIR}/bin")
if("${_bm_pref_lib}" STREQUAL "")
	set(_bm_pref_lib "${BUILDMASTER_INSTALL_DIR}/lib")
endif()

add_executable(links_transitive_test
	"${CMAKE_CURRENT_SOURCE_DIR}/links_transitive_test.c"
)
target_include_directories(links_transitive_test PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(links_transitive_test PRIVATE TransLeaf)
set_target_properties(links_transitive_test PROPERTIES
	BUILD_RPATH "${_bm_pref_lib}"
	INSTALL_RPATH "${_bm_pref_lib}"
)
if(NOT WIN32 AND NOT APPLE)
	target_link_options(links_transitive_test PRIVATE
		"LINKER:--no-allow-shlib-undefined"
	)
elseif(APPLE)
	target_link_options(links_transitive_test PRIVATE "LINKER:-undefined,error")
endif()
add_dependencies(links_transitive_test TransLeaf_install)

if(WIN32)
	add_custom_target(links_transitive_test_run
		COMMAND ${CMAKE_COMMAND} -E env
			"PATH=${_bm_pref_bin};${_bm_pref_lib};$ENV{PATH}"
			$<TARGET_FILE:links_transitive_test>
		DEPENDS links_transitive_test
		COMMENT "[BuildMaster/Core     ]: run links_transitive_test (Win PATH)"
	)
else()
	add_custom_target(links_transitive_test_run
		COMMAND ${CMAKE_COMMAND} -E env
			"DYLD_LIBRARY_PATH=${_bm_pref_lib}:$ENV{DYLD_LIBRARY_PATH}"
			"LD_LIBRARY_PATH=${_bm_pref_lib}:$ENV{LD_LIBRARY_PATH}"
			$<TARGET_FILE:links_transitive_test>
		DEPENDS links_transitive_test
		COMMENT "[BuildMaster/Core     ]: run links_transitive_test"
	)
endif()
