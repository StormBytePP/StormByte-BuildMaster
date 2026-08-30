# After _bm_graph_finalize. Contract:
#   - priv-h is PRIVATE: no INTERFACE includes, srcdir not in parent flags
#   - priv-consumer OPTIONS contain -I<priv-h srcdir>
#   - a registered sibling without that link must not have that -I

_bm_log_message(CORE LOWLEVEL "Entering check_private_headers")

if(NOT TARGET priv-h)
    _bm_log_message(CORE FATAL "check_private_headers: target priv-h missing")
endif()

get_property(_iface TARGET priv-h PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
if(_iface)
    _bm_log_message(CORE FATAL
        "check_private_headers: priv-h INTERFACE_INCLUDE_DIRECTORIES leaked (${_iface})")
endif()

get_property(_srcdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_priv-h_SRCDIR)
_bm_path_normalize(_srcdir "${_srcdir}")
if("${_srcdir}" STREQUAL "")
    _bm_log_message(CORE FATAL "check_private_headers: priv-h SRCDIR empty")
endif()

foreach(_var CMAKE_C_FLAGS CMAKE_CXX_FLAGS)
    if(DEFINED ${_var} AND "${${_var}}" MATCHES "${_srcdir}")
        _bm_log_message(CORE FATAL
            "check_private_headers: parent ${_var} contains private srcdir")
    endif()
endforeach()

get_property(_opts GLOBAL PROPERTY BUILDMASTER_COMPONENT_priv-consumer_OPTIONS)
set(_hit FALSE)
foreach(_o IN LISTS _opts)
    if(_o MATCHES "-I${_srcdir}" OR _o MATCHES "-I${_srcdir}( |$)")
        set(_hit TRUE)
    endif()
    string(FIND "${_o}" "${_srcdir}" _at)
    if(NOT _at EQUAL -1)
        set(_hit TRUE)
    endif()
endforeach()
if(NOT _hit)
    _bm_log_message(CORE FATAL
        "check_private_headers: priv-consumer OPTIONS missing -I for '${_srcdir}' (got '${_opts}')")
endif()

_bm_log_message(CORE STATUS "private-headers contract: OK")
_bm_log_message(CORE LOWLEVEL "Exiting check_private_headers")
