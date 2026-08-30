# BUILDONLY component: builds (with -static OUTPUT_NAME → RENAME) but does not
# install into BUILDMASTER_INSTALL_*.

set(_bo_src "${CMAKE_CURRENT_SOURCE_DIR}/lib")

_bm_backend_cmake_create(
	buildonly-lib
	"Harness BUILDONLY library"
	"${_bo_src}"
	""
	static
	"bolib"
	"BUILDONLY"
)
