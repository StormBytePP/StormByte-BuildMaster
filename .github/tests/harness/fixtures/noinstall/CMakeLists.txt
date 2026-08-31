# NOINSTALL component: builds (with -static OUTPUT_NAME → RENAME) but does not
# install into BUILDMASTER_INSTALL_*.

set(_ni_src "${CMAKE_CURRENT_SOURCE_DIR}/lib")

_bm_backend_cmake_create(
	noinstall-lib
	"Harness NOINSTALL library"
	"${_ni_src}"
	""
	static
	"bolib"
	"NOINSTALL"
)
