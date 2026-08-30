cmake_minimum_required(VERSION 3.20)
project(neg_hash_mismatch LANGUAGES C)

add_subdirectory("${BM_TEST_REPO_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bm")
include("${BM_TEST_REPO_ROOT}/helpers.cmake")

set(_payload "${CMAKE_CURRENT_BINARY_DIR}/payload.bin")
file(WRITE "${_payload}" "buildmaster-hash-mismatch-payload\n")
file(TO_CMAKE_PATH "${_payload}" _payload_cmake)
set(_url "file://${_payload_cmake}")

buildmaster_component(
    hash-mismatch-lib
    "Harness hash mismatch"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    ""
    static
    "hashmismatch"
    "FILES={URL=${_url};NAME=payload;EXPECTED_HASH=SHA256=0000000000000000000000000000000000000000000000000000000000000000}"
)

_bm_materialize_finalize()
