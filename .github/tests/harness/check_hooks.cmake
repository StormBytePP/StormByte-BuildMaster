# Contract: alias order + CAPTURE after explicit finalize.

set(_stamp "${CMAKE_BINARY_DIR}/harness_hooks.stamp")
if(NOT EXISTS "${_stamp}")
    message(FATAL_ERROR "hooks: stamp missing (${_stamp})")
endif()
file(READ "${_stamp}" _body)
string(REPLACE "\r" "" _body "${_body}")

# aa-mat:a before zz-mat:a
string(FIND "${_body}" "aa-mat:a" _aa)
string(FIND "${_body}" "zz-mat:a" _zz)
if(_aa LESS 0 OR _zz LESS 0)
    message(FATAL_ERROR "hooks: missing materialize lines\n${_body}")
endif()
if(_aa GREATER _zz)
    message(FATAL_ERROR "hooks: alias order broken (aa after zz)\n${_body}")
endif()

string(FIND "${_body}" "aa-mat:b" _ab)
if(_ab LESS 0)
    message(FATAL_ERROR "hooks: missing hook-b materialize\n${_body}")
endif()

string(FIND "${_body}" "aa-graph" _ga)
string(FIND "${_body}" "zz-graph" _gz)
if(_ga LESS 0 OR _gz LESS 0)
    message(FATAL_ERROR "hooks: missing graph lines\n${_body}")
endif()
if(_ga GREATER _gz)
    message(FATAL_ERROR "hooks: graph alias order broken\n${_body}")
endif()

message(STATUS "[BuildMaster/Core     ]: hooks stamp OK")
