# Crypto analogue: host is a REAL shared lib in this process, not a BM
# component. Only buildmaster_link(cryptohost SharedBuffer).

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/buffer"
	"${CMAKE_CURRENT_BINARY_DIR}/buffer")

include(GNUInstallDirs)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

set(_bm_pref_lib "${BUILDMASTER_INSTALL_LIBDIR}")
set(_bm_pref_bin "${BUILDMASTER_INSTALL_DIR}/bin")
if("${_bm_pref_lib}" STREQUAL "")
	set(_bm_pref_lib "${BUILDMASTER_INSTALL_DIR}/lib")
endif()

add_library(cryptohost SHARED
	"${CMAKE_CURRENT_SOURCE_DIR}/host/host.c"
)
target_include_directories(cryptohost PUBLIC
	"${CMAKE_CURRENT_SOURCE_DIR}/host"
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
set_target_properties(cryptohost PROPERTIES
	BUILD_RPATH "${_bm_pref_lib}"
	INSTALL_RPATH "${_bm_pref_lib}"
	BUILD_WITH_INSTALL_RPATH FALSE
)
if(NOT WIN32 AND NOT APPLE)
	target_link_options(cryptohost PRIVATE
		"LINKER:--no-allow-shlib-undefined"
	)
elseif(APPLE)
	target_link_options(cryptohost PRIVATE "LINKER:-undefined,error")
endif()
buildmaster_link(cryptohost SharedBuffer)
add_dependencies(cryptohost SharedBuffer_install)

add_executable(links_shared_chain_test
	"${CMAKE_CURRENT_SOURCE_DIR}/links_shared_chain_test.c"
)
target_include_directories(links_shared_chain_test PRIVATE
	"${CMAKE_CURRENT_SOURCE_DIR}/host"
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(links_shared_chain_test PRIVATE cryptohost)
set_target_properties(links_shared_chain_test PROPERTIES
	BUILD_RPATH "${_bm_pref_lib};$<TARGET_FILE_DIR:cryptohost>"
	INSTALL_RPATH "${_bm_pref_lib}"
)
if(NOT WIN32 AND NOT APPLE)
	target_link_options(links_shared_chain_test PRIVATE
		"LINKER:--no-allow-shlib-undefined"
	)
elseif(APPLE)
	target_link_options(links_shared_chain_test PRIVATE "LINKER:-undefined,error")
endif()
add_dependencies(links_shared_chain_test SharedBuffer_install)

if(WIN32)
	add_custom_target(links_shared_chain_test_run
		COMMAND ${CMAKE_COMMAND} -E env
			"PATH=$<TARGET_FILE_DIR:cryptohost>;${_bm_pref_bin};${_bm_pref_lib};$ENV{PATH}"
			$<TARGET_FILE:links_shared_chain_test>
		DEPENDS links_shared_chain_test
		COMMENT "[BuildMaster/Core     ]: run links_shared_chain_test (Win PATH)"
	)
else()
	add_custom_target(links_shared_chain_test_run
		COMMAND ${CMAKE_COMMAND} -E env
			"DYLD_LIBRARY_PATH=${_bm_pref_lib}:$<TARGET_FILE_DIR:cryptohost>:$ENV{DYLD_LIBRARY_PATH}"
			"LD_LIBRARY_PATH=${_bm_pref_lib}:$<TARGET_FILE_DIR:cryptohost>:$ENV{LD_LIBRARY_PATH}"
			$<TARGET_FILE:links_shared_chain_test>
		DEPENDS links_shared_chain_test
		COMMENT "[BuildMaster/Core     ]: run links_shared_chain_test"
	)
endif()
