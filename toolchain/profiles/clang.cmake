# BuildMaster toolchain profile: clang
# LLD is mandatory on Linux; not forced on macOS (Apple ld)

set(BM_TC_C_COMPILER "clang")
set(BM_TC_CXX_COMPILER "clang++")
set(BM_TC_AR "llvm-ar")
set(BM_TC_RANLIB "llvm-ranlib")
set(BM_TC_NM "llvm-nm")

if(APPLE)
	set(BM_TC_FORCE_LLD FALSE)
	set(BM_TC_LINKER_TYPE "")
	set(BM_TC_LINKER "")
else()
	set(BM_TC_FORCE_LLD TRUE)
	set(BM_TC_LINKER_TYPE "LLD")
	set(BM_TC_LINKER "ld.lld")
endif()
