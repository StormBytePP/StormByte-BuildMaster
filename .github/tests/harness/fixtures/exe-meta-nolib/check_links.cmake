# Contract: mode=executable never writes produced stems into links/.
# A non-empty LIBNAMES reintroduces gzip.exe on the parent link line.
if("${BUILDMASTER_LINKS_DIR}" STREQUAL "")
    message(FATAL_ERROR "exe-meta-nolib: BUILDMASTER_LINKS_DIR empty")
endif()
set(_f "${BUILDMASTER_LINKS_DIR}/em-exe.cmake")
if(NOT EXISTS "${_f}")
    message(FATAL_ERROR "exe-meta-nolib: missing ${_f}")
endif()
file(READ "${_f}" _txt)
if("${_txt}" MATCHES "set\\(_BM_LINKS_LIBNAMES \"([^\"]+)\"\\)")
    message(FATAL_ERROR
        "exe-meta-nolib: em-exe LIBNAMES must be empty, got '${CMAKE_MATCH_1}'\n  ${_f}")
endif()
set(_fm "${BUILDMASTER_LINKS_DIR}/em-meta.cmake")
if(EXISTS "${_fm}")
    file(READ "${_fm}" _mt)
    if("${_mt}" MATCHES "emexe")
        message(FATAL_ERROR
            "exe-meta-nolib: em-meta links file mentions emexe\n  ${_fm}")
    endif()
endif()
message(STATUS "[BuildMaster/Core     ]: exe-meta-nolib: executable stems kept off links/")
