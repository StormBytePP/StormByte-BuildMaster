if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
		ABSOLUTE
	)
endif()

_bm_path_builddir(NEST_CMAKE_BUILD_DIR "nest-cmake")
_bm_backend_cmake_create(
	nest-cmake
	"Recursive cmake nest"
	"${CMAKE_CURRENT_SOURCE_DIR}/nest"
	"${NEST_CMAKE_BUILD_DIR}"
	"-DBUILDMASTER_ROOT=${BM_TEST_REPO_ROOT}"
	static
	"recursive/cmake/nestlib"
)
buildmaster_link(nest-cmake "recursive/cmake/midlib")
buildmaster_link(nest-cmake "recursive/cmake/leaflib")

add_executable(recursion_cmake_link_test
	"${CMAKE_CURRENT_SOURCE_DIR}/recursion_cmake_link_test.c"
)
target_link_libraries(recursion_cmake_link_test PRIVATE nest-cmake)
