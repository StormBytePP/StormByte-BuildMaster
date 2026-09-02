# BuildMaster toolchain profile: clang-cl (Windows)
# Forced triple: clang-cl + lld-link + llvm-lib.

set(BM_TC_C_COMPILER "clang-cl")
set(BM_TC_CXX_COMPILER "clang-cl")
set(BM_TC_LINKER_TYPE "LLD")
set(BM_TC_LINKER "lld-link")
set(BM_TC_AR "llvm-lib")
set(BM_TC_RANLIB "")
set(BM_TC_NM "llvm-nm")
set(BM_TC_FORCE_LLD TRUE)
set(BM_TC_FUSE_LD "lld")
