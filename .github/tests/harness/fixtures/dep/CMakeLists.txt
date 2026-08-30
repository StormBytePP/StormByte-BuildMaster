_bm_backend_cmake_create(
	dep
	"Harness dependant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	""
	static
	"deplib"
)
buildmaster_depend(dep base)