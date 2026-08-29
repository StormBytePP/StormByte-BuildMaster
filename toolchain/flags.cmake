# =============================================================================
# toolchain/flags.cmake — flag sanitizers and -fuse-ld mapping
# =============================================================================

## @brief Strip linker-flag tokens that are invalid for a given toolchain.
## @param[out] out_flags Parent-scope variable receiving the cleaned flags string.
## @param[in] flags Original linker flags (may be empty).
## @param[in] toolchain_name Normalized toolchain name (`gcc`, `clang`,
##            `clang-cl`, `msvc`).
## @note Does not clear the entire flag string. Only removes known-incoherent
##       tokens for that profile. Unknown tokens are preserved.
## @note `msvc`: drops Clang/LLVM LTO and `-fuse-ld=*` tokens.
## @note `clang-cl`: drops MSVC LTCG / `/GL` tokens that `lld-link` rejects.
function(buildmaster_clean_ldflags out_flags flags toolchain_name)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_clean_ldflags")
	set(_f "${flags}")

	if(toolchain_name STREQUAL "msvc")
		foreach(_tok
			"-fuse-ld=lld"
			"-fuse-ld=lld-link"
			"-fuse-ld=link"
			"-flto"
			"-flto=thin"
			"-flto=full"
			"/clang:-flto"
			"/clang:-flto=thin"
			"/clang:-flto=full"
			"/clang:-fuse-ld=lld"
			"/clang:-fuse-ld=lld-link"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	elseif(toolchain_name STREQUAL "clang-cl")
		# MSVC LTCG link flags are ignored / wrong with lld-link
		foreach(_tok
			"/LTCG"
			"/LTCG:INCREMENTAL"
			"/LTCG:STATUS"
			"/LTCG:OFF"
			"/GL"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	endif()

	set(${out_flags} "${_f}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_clean_ldflags")
endfunction()

## @brief Strip compile-flag tokens that are invalid for a given toolchain.
## @param[out] out_flags Parent-scope variable receiving the cleaned flags string.
## @param[in] flags Original C or CXX flags (may be empty).
## @param[in] toolchain_name Normalized toolchain name (`gcc`, `clang`,
##            `clang-cl`, `msvc`).
## @note Does not clear the entire flag string.
## @note `msvc`: removes known Clang/LLVM-only switches (including `/clang:*`
##       and `-fthinlto-index=*`).
## @note `clang-cl`: removes MSVC whole-program LTCG compile switches (`/GL`,
##       `/LTCG*`) that clang-cl reports as “unknown argument ignored”.
function(buildmaster_clean_cflags out_flags flags toolchain_name)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_clean_cflags")
	set(_f "${flags}")

	if(toolchain_name STREQUAL "msvc")
		foreach(_tok
			"-flto"
			"-flto=thin"
			"-flto=full"
			"-fuse-ld=lld"
			"-fuse-ld=lld-link"
			"-fuse-ld=link"
			"-fthinlto-index="
			"-fwhole-program-vtables"
			"-fvirtual-function-elimination"
			"-fstrict-vtable-pointers"
			"-fno-split-lto-unit"
			"-fsplit-lto-unit"
			"/clang:-flto"
			"/clang:-flto=thin"
			"/clang:-flto=full"
			"/clang:-fuse-ld=lld"
			"/clang:-fuse-ld=lld-link"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "/clang:[^ \t]+" "" _f "${_f}")
		string(REGEX REPLACE "-fthinlto-index=[^ \t]*" "" _f "${_f}")
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	elseif(toolchain_name STREQUAL "clang-cl")
		foreach(_tok
			"/GL"
			"/LTCG"
			"/LTCG:INCREMENTAL"
			"/LTCG:STATUS"
			"/LTCG:OFF"
		)
			string(REPLACE "${_tok}" "" _f "${_f}")
		endforeach()
		string(REGEX REPLACE "[ \t]+" " " _f "${_f}")
		string(STRIP "${_f}" _f)
	endif()

	set(${out_flags} "${_f}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_clean_cflags")
endfunction()

## @brief Map linker type/path to a driver-safe `-fuse-ld=` flag for Meson/CMake.
## @param[out] out_flag Parent-scope variable receiving e.g. `-fuse-ld=lld`,
##            or empty when the system default linker must be used.
## @param[in] linker_type Optional `CMAKE_LINKER_TYPE` / `BM_TC_LINKER_TYPE`
##            (`LLD`, `MSVC`, …). May be empty.
## @param[in] linker Optional `CMAKE_LINKER` / `BM_TC_LINKER` path or short name.
## @note GCC rejects absolute paths such as `-fuse-ld=/usr/bin/ld`. Only emit
##       flavor names the compiler driver understands (`lld`, `gold`, `mold`,
##       `bfd`, `link`). System `ld` and unknown paths yield an empty flag so
##       Meson keeps the default linker.
function(buildmaster_fuse_ld_flag out_flag linker_type linker)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_fuse_ld_flag")
	set(_flag "")
	string(STRIP "${linker_type}" _lt)
	string(TOUPPER "${_lt}" _lt)
	string(STRIP "${linker}" _lnk)

	if(_lt STREQUAL "LLD")
		if(WIN32)
			set(_flag "-fuse-ld=lld-link")
		else()
			set(_flag "-fuse-ld=lld")
		endif()
	elseif(_lt STREQUAL "MSVC")
		set(_flag "-fuse-ld=link")
	elseif(NOT _lnk STREQUAL "")
		get_filename_component(_base "${_lnk}" NAME)
		string(TOLOWER "${_base}" _base)
		string(REGEX REPLACE "\\.exe$" "" _base "${_base}")

		if(_base STREQUAL "lld" OR _base STREQUAL "ld.lld")
			if(WIN32)
				set(_flag "-fuse-ld=lld-link")
			else()
				set(_flag "-fuse-ld=lld")
			endif()
		elseif(_base STREQUAL "lld-link")
			set(_flag "-fuse-ld=lld-link")
		elseif(_base STREQUAL "gold" OR _base STREQUAL "ld.gold")
			set(_flag "-fuse-ld=gold")
		elseif(_base STREQUAL "mold")
			set(_flag "-fuse-ld=mold")
		elseif(_base STREQUAL "bfd" OR _base STREQUAL "ld.bfd")
			set(_flag "-fuse-ld=bfd")
		elseif(_base STREQUAL "link")
			if(WIN32)
				set(_flag "-fuse-ld=link")
			endif()
		endif()
		# basename "ld" or unknown absolute paths: leave empty
	endif()

	set(${out_flag} "${_flag}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_fuse_ld_flag")
endfunction()
