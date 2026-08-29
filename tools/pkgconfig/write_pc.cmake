# =============================================================================
# tools/pkgconfig/write_pc.cmake
# =============================================================================
# cmake -DPC_NAME= -DPC_VERSION= -DPC_DESCRIPTION= -DPC_LIBS=
#       -DPC_REQUIRES= -DPC_CFLAGS= -DPREFIX= -DLIBDIR= -DINCLUDEDIR=
#       -DOUT= -DBUILDMASTER_SRCDIR= -P write_pc.cmake
#
# Writes one helper .pc for an internal BM component. FATAL if OUT already
# exists (upstream already shipped a file — do not clobber).

if(BUILDMASTER_SRCDIR)
	include("${BUILDMASTER_SRCDIR}/log.cmake")
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
	include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
endif()
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

if(NOT PC_NAME OR NOT PC_VERSION OR NOT PREFIX OR NOT OUT OR NOT LIBDIR)
	_bm_log_message(COMPONENT FATAL
		"write_pc: need -DPC_NAME= -DPC_VERSION= -DPREFIX= -DLIBDIR= -DOUT=")
endif()

if(NOT PC_DESCRIPTION)
	set(PC_DESCRIPTION "${PC_NAME}")
endif()
if(NOT INCLUDEDIR)
	set(INCLUDEDIR "include")
endif()
if(NOT PC_LIBS)
	set(PC_LIBS "")
endif()
if(NOT PC_REQUIRES)
	set(PC_REQUIRES "")
endif()
if(NOT PC_CFLAGS)
	set(PC_CFLAGS "")
endif()

if(EXISTS "${OUT}")
	_bm_log_message(COMPONENT FATAL
		"write_pc: '${OUT}' already exists (upstream .pc). BuildMaster will not overwrite it. Use PC={ENABLED=FALSE} or drop PC={…}.")
endif()

get_filename_component(_pc_dir "${OUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_pc_dir}")

set(_body "")
string(APPEND _body "prefix=${PREFIX}\n")
string(APPEND _body "exec_prefix=\${prefix}\n")
string(APPEND _body "libdir=\${prefix}/${LIBDIR}\n")
string(APPEND _body "includedir=\${prefix}/${INCLUDEDIR}\n")
string(APPEND _body "\n")
string(APPEND _body "Name: ${PC_NAME}\n")
string(APPEND _body "Description: ${PC_DESCRIPTION}\n")
string(APPEND _body "Version: ${PC_VERSION}\n")
if(NOT PC_REQUIRES STREQUAL "")
	string(APPEND _body "Requires: ${PC_REQUIRES}\n")
endif()
if(NOT PC_LIBS STREQUAL "")
	string(APPEND _body "Libs: -L\${libdir} ${PC_LIBS}\n")
else()
	string(APPEND _body "Libs: -L\${libdir}\n")
endif()
if(NOT PC_CFLAGS STREQUAL "")
	string(APPEND _body "Cflags: ${PC_CFLAGS}\n")
endif()

file(WRITE "${OUT}" "${_body}")
_bm_log_message(COMPONENT INFO "wrote helper .pc ${OUT}")
