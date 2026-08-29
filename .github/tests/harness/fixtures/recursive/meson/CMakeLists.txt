if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

_bm_path_builddir(NEST_MESON_BUILD_DIR "nest-meson")
_bm_backend_cmake_create(
	nest-meson
	"Recursive meson nest"
	"${CMAKE_CURRENT_SOURCE_DIR}/nest"
	"${NEST_MESON_BUILD_DIR}"
	"-DBUILDMASTER_ROOT=${BM_TEST_REPO_ROOT}"
	static
	"recursive/meson/nestlib"
)
buildmaster_link(nest-meson "recursive/meson/midlib")
buildmaster_link(nest-meson "recursive/meson/leaflib")

add_executable(recursion_meson_link_test
	"${CMAKE_CURRENT_SOURCE_DIR}/recursion_meson_link_test.c"
)
target_link_libraries(recursion_meson_link_test PRIVATE nest-meson)