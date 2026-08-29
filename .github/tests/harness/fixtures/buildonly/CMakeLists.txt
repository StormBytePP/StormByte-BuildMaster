# BUILDONLY component: builds (with -static OUTPUT_NAME → RENAME) but does not
# install into BUILDMASTER_INSTALL_*.

set(_bo_src "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(_bo_build "${CMAKE_CURRENT_BINARY_DIR}/lib_build")
file(MAKE_DIRECTORY "${_bo_build}")

_bm_backend_cmake_create(
	buildonly-lib
	"Harness BUILDONLY library"
	"${_bo_src}"
	"${_bo_build}"
	""
	static
	"bolib"
	"BUILDONLY"
)