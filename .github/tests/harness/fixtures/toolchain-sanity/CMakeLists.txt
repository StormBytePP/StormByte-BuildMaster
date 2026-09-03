# Configure-time. Generated Meson native files + profile sources.
# Profile .cmake files contain BOTH Darwin and Linux branches; do not
# assert absence of Linux tokens in the source. Assert the generated
# native_*.ini instead.
# native_<profile>.ini exists only after that profile is demanded
# (parent job, TOOLCHAIN=, or this fixture when the binaries exist).

function(_bm_tc_sanity_slurp path out_var)
	if(NOT EXISTS "${path}")
		_bm_log_message(CORE FATAL "toolchain-sanity: missing ${path}")
	endif()
	file(READ "${path}" _txt)
	set(${out_var} "${_txt}" PARENT_SCOPE)
endfunction()

function(_bm_tc_sanity_must_match hay needle label)
	if(NOT hay MATCHES "${needle}")
		_bm_log_message(CORE FATAL
			"toolchain-sanity ${label}: expected /${needle}/")
	endif()
endfunction()

function(_bm_tc_sanity_must_not hay needle label)
	if(hay MATCHES "${needle}")
		_bm_log_message(CORE FATAL
			"toolchain-sanity ${label}: must not match /${needle}/")
	endif()
endfunction()

if(NOT DEFINED BUILDMASTER_SCRIPTSDIR OR BUILDMASTER_SCRIPTSDIR STREQUAL "")
	_bm_log_message(CORE FATAL "toolchain-sanity: BUILDMASTER_SCRIPTSDIR unset")
endif()
if(NOT DEFINED BUILDMASTER_SRCDIR OR BUILDMASTER_SRCDIR STREQUAL "")
	_bm_log_message(CORE FATAL "toolchain-sanity: BUILDMASTER_SRCDIR unset")
endif()

set(_meson_dir "${BUILDMASTER_SCRIPTSDIR}/meson")
set(_prof_dir "${BUILDMASTER_SRCDIR}/toolchain/profiles")

_bm_tc_infer_profile(_bm_tc_parent)

if(WIN32)
	_bm_tc_demand_profile("msvc" "component:tc-sanity")
	_bm_tc_demand_profile("clang-cl" "component:tc-sanity")

	_bm_tc_sanity_slurp("${_meson_dir}/native_msvc.ini" _msvc_n)
	_bm_tc_sanity_must_match("${_msvc_n}" "lib\\.exe" "native_msvc.ini ar")
	_bm_tc_sanity_must_match("${_msvc_n}" "link\\.exe" "native_msvc.ini ld")
	_bm_tc_sanity_must_not("${_msvc_n}" "llvm-lib" "native_msvc.ini")

	_bm_tc_sanity_slurp("${_prof_dir}/msvc.cmake" _msvc_p)
	_bm_tc_sanity_must_match("${_msvc_p}" "BM_TC_AR \"lib\"" "profile msvc AR")
	_bm_tc_sanity_must_match("${_msvc_p}" "BM_TC_LINKER \"link\"" "profile msvc link")

	_bm_tc_sanity_slurp("${_meson_dir}/native_clang-cl.ini" _cl_n)
	_bm_tc_sanity_must_match("${_cl_n}" "llvm-lib" "native_clang-cl.ini ar")
	_bm_tc_sanity_must_match("${_cl_n}" "lld-link" "native_clang-cl.ini ld")
	_bm_tc_sanity_must_not("${_cl_n}" "[/\\\\]lib\\.exe" "native_clang-cl.ini")

	_bm_tc_sanity_slurp("${_prof_dir}/clang-cl.cmake" _cl_p)
	_bm_tc_sanity_must_match("${_cl_p}" "BM_TC_AR \"llvm-lib\"" "profile clang-cl AR")
	_bm_tc_sanity_must_match("${_cl_p}" "BM_TC_LINKER \"lld-link\"" "profile clang-cl link")

	_bm_log_message(CORE STATUS "toolchain-sanity Windows: msvc + clang-cl OK")
else()
	_bm_tc_demand_profile("gcc" "component:tc-sanity")
	_bm_tc_demand_profile("clang" "component:tc-sanity")

	_bm_tc_sanity_slurp("${_meson_dir}/native_gcc.ini" _gcc_n)
	_bm_tc_sanity_slurp("${_prof_dir}/gcc.cmake" _gcc_p)
	_bm_tc_sanity_must_not("${_gcc_n}" "llvm-ar" "native_gcc.ini")
	_bm_tc_sanity_must_not("${_gcc_n}" "ld\\.lld" "native_gcc.ini")
	_bm_tc_sanity_must_match("${_gcc_n}" "ar" "native_gcc.ini ar")

	if(APPLE)
		_bm_tc_sanity_must_not("${_gcc_n}" "ld\\.bfd" "native_gcc.ini apple")
		_bm_tc_sanity_must_not("${_gcc_n}" "LINKER_TYPE" "native_gcc.ini apple no BFD type")
		_bm_tc_sanity_must_match("${_gcc_p}" "BM_TC_LINKER \"ld\"" "profile gcc apple ld")
	else()
		_bm_tc_sanity_must_match("${_gcc_p}" "BM_TC_AR \"ar\"" "profile gcc AR")
		_bm_tc_sanity_must_match("${_gcc_p}" "BM_TC_FORCE_LLD FALSE" "profile gcc LLD")
		_bm_tc_sanity_must_match("${_gcc_p}" "BM_TC_LINKER_TYPE \"BFD\"" "profile gcc BFD")
	endif()

	_bm_tc_sanity_slurp("${_meson_dir}/native_clang.ini" _clang_n)
	_bm_tc_sanity_slurp("${_prof_dir}/clang.cmake" _clang_p)
	if(APPLE)
		_bm_tc_sanity_must_not("${_clang_n}" "llvm-ar" "native_clang.ini apple")
		_bm_tc_sanity_must_not("${_clang_n}" "ld\\.lld" "native_clang.ini apple")
		_bm_tc_sanity_must_match("${_clang_p}" "BM_TC_AR \"ar\"" "profile clang apple AR")
		_bm_tc_sanity_must_match("${_clang_p}" "BM_TC_LINKER \"ld\"" "profile clang apple ld")
	else()
		_bm_tc_sanity_must_match("${_clang_n}" "llvm-ar" "native_clang.ini ar")
		_bm_tc_sanity_must_match("${_clang_n}" "ld\\.lld" "native_clang.ini lld")
		_bm_tc_sanity_must_match("${_clang_p}" "BM_TC_LINKER \"ld.lld\"" "profile clang lld")
		_bm_tc_sanity_must_match("${_clang_p}" "BM_TC_AR \"llvm-ar\"" "profile clang AR")
	endif()
	_bm_log_message(CORE STATUS
		"toolchain-sanity Unix: parent=${_bm_tc_parent}; gcc + clang demanded OK")
endif()

add_custom_target(tc-sanity
	COMMAND ${CMAKE_COMMAND} -E echo "toolchain-sanity already ran at configure"
)
