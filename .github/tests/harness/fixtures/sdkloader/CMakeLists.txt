_bm_path_builddir(LOADER_BUILD_DIR "sdkloader")
_bm_backend_cmake_create(
	sdkloader
	"Harness SDK loader"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${LOADER_BUILD_DIR}"
	""
	static
	"loaderlib"
)
buildmaster_depend(sdkloader sdk-headers)
