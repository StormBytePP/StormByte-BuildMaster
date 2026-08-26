ensure_build_dir(LOADER_BUILD_DIR "sdkloader")
create_cmake_component(
	sdkloader
	"Harness SDK loader"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${LOADER_BUILD_DIR}"
	""
	static
	"loaderlib"
)
component_dependency(sdkloader sdk-headers)
