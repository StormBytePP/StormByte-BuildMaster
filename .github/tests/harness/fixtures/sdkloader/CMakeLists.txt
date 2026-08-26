ensure_build_dir(LOADER_BUILD_DIR "sdkloader")
create_cmake_dependant_component(
	LOADER_FILE
	sdkloader
	"Harness SDK loader"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${LOADER_BUILD_DIR}"
	""
	static
	"loaderlib"
	"sdk-headers_install"
)
include("${LOADER_FILE}")