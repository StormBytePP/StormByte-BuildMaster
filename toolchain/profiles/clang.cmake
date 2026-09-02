# BuildMaster toolchain profile: clang
# Forced triple: clang + ld.lld + llvm-ar. No BFD, no Apple ld fallback.

set(BM_TC_C_COMPILER "clang")
set(BM_TC_CXX_COMPILER "clang++")
set(BM_TC_AR "llvm-ar")
set(BM_TC_RANLIB "llvm-ranlib")
set(BM_TC_NM "llvm-nm")
set(BM_TC_FORCE_LLD TRUE)
set(BM_TC_LINKER_TYPE "LLD")
set(BM_TC_LINKER "ld.lld")
set(BM_TC_FUSE_LD "lld")
