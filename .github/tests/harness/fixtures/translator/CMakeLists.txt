# Configure-time only. Calls _bm_tc_translate_flags; no compile.

## @brief FATAL unless `hay` matches `needle`.
function(_bm_tc_tr_must_match hay needle label)
	if(NOT hay MATCHES "${needle}")
		_bm_log_message(CORE FATAL
			"translator ${label}: expected /${needle}/ in '${hay}'")
	endif()
endfunction()

## @brief FATAL if `hay` matches `needle`.
function(_bm_tc_tr_must_not hay needle label)
	if(hay MATCHES "${needle}")
		_bm_log_message(CORE FATAL
			"translator ${label}: must not match /${needle}/ in '${hay}'")
	endif()
endfunction()

if(NOT COMMAND _bm_tc_translate_flags)
	_bm_log_message(CORE FATAL
		"translator: _bm_tc_translate_flags missing (include toolchain/translator.cmake)")
endif()

set(_bm_ipo_save "")
if(DEFINED CMAKE_INTERPROCEDURAL_OPTIMIZATION)
	set(_bm_ipo_save "${CMAKE_INTERPROCEDURAL_OPTIMIZATION}")
endif()
set(_bm_ipo_rel_save "")
if(DEFINED CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
	set(_bm_ipo_rel_save "${CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE}")
endif()
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE OFF)

# ----- msvc, IPO off: no IPO tokens in input -----
set(_c "-fPIC -I/opt/inc -Wall")
set(_cxx "-fPIC")
set(_ld "-fuse-ld=link -L/opt/lib")
_bm_tc_translate_flags(_c _cxx _ld "msvc")
_bm_tc_tr_must_not("${_c}" "-fPIC" "msvc c -fPIC")
_bm_tc_tr_must_not("${_c}" "-Wall" "msvc c -Wall")
_bm_tc_tr_must_match("${_c}" "/I/opt/inc" "msvc c /I")
_bm_tc_tr_must_not("${_ld}" "-fuse-ld" "msvc ld fuse-ld")
_bm_tc_tr_must_not("${_ld}" "/LTCG" "msvc ld IPO off")
_bm_tc_tr_must_not("${_c}" "/GL" "msvc c IPO off")
_bm_tc_tr_must_match("${_ld}" "/LIBPATH:/opt/lib" "msvc ld /LIBPATH")

# ----- gcc, IPO off: no IPO tokens in input -----
set(_c "/O2 /I/opt/inc -fPIC")
set(_cxx "-O2")
set(_ld "/LIBPATH:/opt/lib -fuse-ld=lld")
_bm_tc_translate_flags(_c _cxx _ld "gcc")
_bm_tc_tr_must_not("${_c}" "/O2" "gcc c /O2")
_bm_tc_tr_must_match("${_c}" "-I/opt/inc" "gcc c -I")
_bm_tc_tr_must_match("${_c}" "-fPIC" "gcc c -fPIC")
_bm_tc_tr_must_not("${_ld}" "-fuse-ld" "gcc ld fuse-ld")
_bm_tc_tr_must_match("${_ld}" "-L/opt/lib" "gcc ld -L")
_bm_tc_tr_must_not("${_c}" "-flto" "gcc c IPO off")
_bm_tc_tr_must_not("${_ld}" "/LTCG" "gcc ld IPO off")

# ----- clang-cl, IPO off -----
set(_c "-I/opt/inc")
set(_cxx "")
set(_ld "-fuse-ld=lld")
_bm_tc_translate_flags(_c _cxx _ld "clang-cl")
_bm_tc_tr_must_not("${_c}" "/GL" "clang-cl c /GL")
_bm_tc_tr_must_not("${_ld}" "/LTCG" "clang-cl ld /LTCG")
_bm_tc_tr_must_not("${_ld}" "-fuse-ld" "clang-cl ld fuse-ld")

# ----- IPO on via CMake var -----
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
set(_c "-O2")
set(_cxx "-O2")
set(_ld "")
_bm_tc_translate_flags(_c _cxx _ld "msvc")
_bm_tc_tr_must_match("${_c}" "/GL" "msvc c IPO on")
_bm_tc_tr_must_match("${_ld}" "/LTCG" "msvc ld IPO on")

set(_c "-O2")
set(_cxx "-O2")
set(_ld "")
_bm_tc_translate_flags(_c _cxx _ld "gcc")
_bm_tc_tr_must_match("${_c}" "-flto" "gcc c IPO on")
_bm_tc_tr_must_match("${_ld}" "-flto" "gcc ld IPO on")
_bm_tc_tr_must_not("${_c}" "/GL" "gcc c IPO on no /GL")

set(_c "-O2")
set(_cxx "-O2")
set(_ld "")
_bm_tc_translate_flags(_c _cxx _ld "clang")
_bm_tc_tr_must_match("${_c}" "-flto" "clang c IPO on")

set(_c "-O2")
set(_cxx "-O2")
set(_ld "")
_bm_tc_translate_flags(_c _cxx _ld "clang-cl")
_bm_tc_tr_must_match("${_c}" "-flto" "clang-cl c IPO on")
_bm_tc_tr_must_not("${_ld}" "/LTCG" "clang-cl ld IPO on no /LTCG")

# ----- IPO on via input token, CMake var off -----
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE OFF)
set(_c "-flto")
set(_cxx "")
set(_ld "")
_bm_tc_translate_flags(_c _cxx _ld "msvc")
_bm_tc_tr_must_not("${_c}" "-flto" "msvc from -flto")
_bm_tc_tr_must_match("${_c}" "/GL" "msvc from -flto /GL")
_bm_tc_tr_must_match("${_ld}" "/LTCG" "msvc from -flto /LTCG")

set(CMAKE_INTERPROCEDURAL_OPTIMIZATION "${_bm_ipo_save}")
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE "${_bm_ipo_rel_save}")

_bm_log_message(CORE STATUS "translator: dialect + IPO contracts OK")

add_custom_target(tc-translate
	COMMAND ${CMAKE_COMMAND} -E echo "translator fixture already ran at configure"
)
