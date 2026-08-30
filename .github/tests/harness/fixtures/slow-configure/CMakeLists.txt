_bm_backend_cmake_create(
	slow-configure
	"Harness slow configure"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	""
	static
	"slowlib"
)
# Force build-time configure so Ninja prints the status line.
buildmaster_depend(slow-configure base)
