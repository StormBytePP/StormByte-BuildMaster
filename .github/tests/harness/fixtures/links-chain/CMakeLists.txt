if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/buffer" "${CMAKE_CURRENT_BINARY_DIR}/buffer")

buildmaster_component(
	links-host
	"Harness links host"
	"${CMAKE_CURRENT_SOURCE_DIR}/host"
	""
	static
	"linkshost"
)

buildmaster_link(links-host StormByte-Buffer)

add_executable(links_chain_test
	"${CMAKE_CURRENT_SOURCE_DIR}/links_chain_test.c"
)
target_include_directories(links_chain_test PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(links_chain_test PRIVATE links-host)
add_dependencies(links_chain_test
	links-host_install
	StormByte-Buffer_install
)

add_custom_target(links_chain_test_run
	COMMAND $<TARGET_FILE:links_chain_test>
	DEPENDS links_chain_test
	COMMENT "[BuildMaster/Core     ]: run links_chain_test (host→Buffer only; expect 0)"
)
