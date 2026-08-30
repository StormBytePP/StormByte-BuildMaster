# Configure-time contract: _bm_tools_file_checksum SHA256 / SHA3_256.

set(_hf "${CMAKE_CURRENT_BINARY_DIR}/hash-fixture.bin")
file(WRITE "${_hf}" "buildmaster-hash-fixture\n")

file(SHA256 "${_hf}" _sha256)
file(SHA3_256 "${_hf}" _sha3)

_bm_tools_file_checksum(_ok256 "${_hf}" "SHA256=${_sha256}")
if(NOT _ok256)
    _bm_log_message(CORE FATAL
        "files-hash: SHA256 of a local fixture must match")
endif()

_bm_tools_file_checksum(_ok3 "${_hf}" "SHA3_256=${_sha3}")
if(NOT _ok3)
    _bm_log_message(CORE FATAL
        "files-hash: SHA3_256 of a local fixture must match")
endif()

_bm_tools_file_checksum(_bad "${_hf}"
    "SHA256=0000000000000000000000000000000000000000000000000000000000000000")
if(_bad)
    _bm_log_message(CORE FATAL
        "files-hash: wrong SHA256 must be a mismatch")
endif()

_bm_log_message(CORE STATUS "files-hash contract: OK")
