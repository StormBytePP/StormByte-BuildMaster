cmake_minimum_required(VERSION 3.20)
project(neg_files_on_meta LANGUAGES C)

add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")

buildmaster_meta(bad-meta "FILES on meta must FATAL"
	"FILES={URL=https://example.invalid/x.tar.gz;NAME=x}")

_bm_materialize_finalize()
