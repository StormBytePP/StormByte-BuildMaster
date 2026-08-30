_bm_backend_cmake_create(
	sdkloader
	"Harness SDK loader"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	""
	static
	"loaderlib"
)
buildmaster_depend(sdkloader sdk-headers)
