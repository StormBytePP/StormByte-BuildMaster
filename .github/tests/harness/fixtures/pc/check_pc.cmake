# cmake -DDEP_PC= -DLIB_PC= -P check_pc.cmake
# Contract: helper .pc exists and lib Requires names the dep package.

if(NOT DEP_PC OR NOT LIB_PC)
	message(FATAL_ERROR "check_pc: need -DDEP_PC= and -DLIB_PC=")
endif()

if(NOT EXISTS "${DEP_PC}")
	message(FATAL_ERROR "check_pc: missing ${DEP_PC}")
endif()
if(NOT EXISTS "${LIB_PC}")
	message(FATAL_ERROR "check_pc: missing ${LIB_PC}")
endif()

file(READ "${DEP_PC}" _dep)
file(READ "${LIB_PC}" _lib)

if(NOT _dep MATCHES "Name: pcdep")
	message(FATAL_ERROR "check_pc: ${DEP_PC} missing Name: pcdep\n${_dep}")
endif()
if(NOT _dep MATCHES "Version: 1.0.0")
	message(FATAL_ERROR "check_pc: ${DEP_PC} missing Version: 1.0.0\n${_dep}")
endif()
if(NOT _lib MATCHES "Name: pclib")
	message(FATAL_ERROR "check_pc: ${LIB_PC} missing Name: pclib\n${_lib}")
endif()
if(NOT _lib MATCHES "Version: 2.0.0")
	message(FATAL_ERROR "check_pc: ${LIB_PC} missing Version: 2.0.0\n${_lib}")
endif()
if(NOT _lib MATCHES "Requires:.*pcdep")
	message(FATAL_ERROR "check_pc: ${LIB_PC} missing Requires: pcdep\n${_lib}")
endif()
