cmake_minimum_required(VERSION 3.20)
project(neg_pc_clobber LANGUAGES C)

add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")

_bm_backend_cmake_create(
	pc-clash
	"Harness PC clobber"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${CMAKE_CURRENT_BINARY_DIR}/pc-clash"
	""
	static
	"pcclashlib"
	"PC={VERSION=1.0.0;NAME=pcclash}"
)

_bm_graph_finalize()
