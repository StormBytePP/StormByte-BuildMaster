# Basic synthetic components + recursive chains + rename normalize.
# Included from the harness after BuildMaster helpers are available.

if(NOT BM_TEST_REPO_ROOT)
	get_filename_component(BM_TEST_REPO_ROOT
		"${CMAKE_CURRENT_SOURCE_DIR}/../../.."
		ABSOLUTE
	)
endif()

# ---------------------------------------------------------------------------
# Flat components (component id ≠ imported subcomponent name)
# ---------------------------------------------------------------------------

ensure_build_dir(BASE_BUILD_DIR "base")
create_cmake_component(
	BASE_FILE
	base
	"Harness base library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib_base"
	"${BASE_BUILD_DIR}"
	""
	static
	"baselib"
)
include("${BASE_FILE}")

ensure_build_dir(DEP_BUILD_DIR "dep")
create_cmake_dependant_component(
	DEP_FILE
	dep
	"Harness dependant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib_dep"
	"${DEP_BUILD_DIR}"
	""
	static
	"deplib"
	"base_install"
)
include("${DEP_FILE}")

ensure_build_dir(HEADERS_BUILD_DIR "sdk-headers")
create_cmake_headers_component(
	HEADERS_FILE
	sdk-headers
	"Harness SDK headers"
	"${CMAKE_CURRENT_SOURCE_DIR}/headers_only"
	"${HEADERS_BUILD_DIR}"
	""
)
include("${HEADERS_FILE}")

ensure_build_dir(LOADER_BUILD_DIR "sdkloader")
create_cmake_dependant_component(
	LOADER_FILE
	sdkloader
	"Harness SDK loader"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib_loader"
	"${LOADER_BUILD_DIR}"
	""
	static
	"loaderlib"
	"sdk-headers_install"
)
include("${LOADER_FILE}")

# ---------------------------------------------------------------------------
# Archive name normalize (Meson installs zs.* → produced z.*)
# ---------------------------------------------------------------------------

add_subdirectory(rename)

# ---------------------------------------------------------------------------
# Recursive chains (cmake nest→mid→leaf, meson nest→mid→meson leaf)
# ---------------------------------------------------------------------------

add_subdirectory(recursive/cmake)
add_subdirectory(recursive/meson)