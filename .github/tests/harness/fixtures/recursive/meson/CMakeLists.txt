if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

ensure_build_dir(NEST_MESON_BUILD_DIR "nest-meson")
create_cmake_component(
	NEST_MESON_FILE
	nest-meson
	"Recursive meson nest"
	"${CMAKE_CURRENT_SOURCE_DIR}/nest"
	"${NEST_MESON_BUILD_DIR}"
	"-DBUILDMASTER_ROOT=${BM_TEST_REPO_ROOT}"
	static
	"recursive/meson/nestlib"
	"LINK_EXTRA=recursive/meson/midlib,recursive/meson/leaflib"
)
include("${NEST_MESON_FILE}")

add_executable(recursion_meson_link_test
	"${CMAKE_CURRENT_SOURCE_DIR}/recursion_meson_link_test.c"
)
target_link_libraries(recursion_meson_link_test PRIVATE nest-meson)
