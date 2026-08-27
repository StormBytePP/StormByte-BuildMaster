# BuildMaster toolchain profile: gcc
# On macOS /usr/bin/gcc is Apple Clang. Use Homebrew gcc-N (highest N).

set(BM_TC_C_COMPILER "gcc")
set(BM_TC_CXX_COMPILER "g++")
set(BM_TC_AR "ar")
set(BM_TC_RANLIB "ranlib")
set(BM_TC_NM "nm")
set(BM_TC_FORCE_LLD FALSE)
set(BM_TC_LINKER_TYPE "")
set(BM_TC_LINKER "")

if(APPLE)
	set(_bm_gcc_hints
		/opt/homebrew/bin
		/usr/local/bin
	)
	if(DEFINED ENV{HOMEBREW_PREFIX} AND NOT "$ENV{HOMEBREW_PREFIX}" STREQUAL "")
		list(APPEND _bm_gcc_hints "$ENV{HOMEBREW_PREFIX}/bin")
	endif()

	set(_bm_best_ver -1)
	set(_bm_best_cc "")
	set(_bm_best_cxx "")

	foreach(_bm_hint IN LISTS _bm_gcc_hints)
		if(NOT IS_DIRECTORY "${_bm_hint}")
			continue()
		endif()
		file(GLOB _bm_gccs "${_bm_hint}/gcc-[0-9]*")
		foreach(_bm_cc IN LISTS _bm_gccs)
			get_filename_component(_bm_name "${_bm_cc}" NAME)
			if(NOT _bm_name MATCHES "^gcc-([0-9]+)$")
				continue()
			endif()
			set(_bm_ver "${CMAKE_MATCH_1}")
			set(_bm_cxx "${_bm_hint}/g++-${_bm_ver}")
			if(NOT EXISTS "${_bm_cxx}")
				continue()
			endif()
			if(_bm_ver GREATER _bm_best_ver)
				set(_bm_best_ver "${_bm_ver}")
				set(_bm_best_cc "${_bm_cc}")
				set(_bm_best_cxx "${_bm_cxx}")
			endif()
		endforeach()
	endforeach()

	if(_bm_best_ver GREATER -1)
		set(BM_TC_C_COMPILER "${_bm_best_cc}")
		set(BM_TC_CXX_COMPILER "${_bm_best_cxx}")
	endif()
endif()
