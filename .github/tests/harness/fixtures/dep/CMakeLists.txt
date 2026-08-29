_bm_path_builddir(DEP_BUILD_DIR "dep")
_bm_backend_cmake_create(
	dep
	"Harness dependant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${DEP_BUILD_DIR}"
	""
	static
	"deplib"
)
buildmaster_depend(dep base)
