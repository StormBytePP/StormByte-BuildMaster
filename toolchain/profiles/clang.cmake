# BuildMaster toolchain profile: clang
# Linux: clang + ld.lld + llvm-ar.
# Darwin: AppleClang + cctools ar/ld. Do not set CMAKE_LINKER_TYPE;
# CMake rejects LINKER_TYPE 'APPLE'. llvm-ar / lld only if that
# binary sits next to the compiler (Homebrew llvm).

set(BM_TC_C_COMPILER "clang")
set(BM_TC_CXX_COMPILER "clang++")

if(APPLE)
	set(BM_TC_AR "ar")
	set(BM_TC_RANLIB "ranlib")
	set(BM_TC_NM "nm")
	set(BM_TC_FORCE_LLD FALSE)
	set(BM_TC_LINKER_TYPE "")
	set(BM_TC_LINKER "ld")
	set(BM_TC_FUSE_LD "")
else()
	set(BM_TC_AR "llvm-ar")
	set(BM_TC_RANLIB "llvm-ranlib")
	set(BM_TC_NM "llvm-nm")
	set(BM_TC_FORCE_LLD TRUE)
	set(BM_TC_LINKER_TYPE "LLD")
	set(BM_TC_LINKER "ld.lld")
	set(BM_TC_FUSE_LD "lld")
endif()
