# BuildMaster toolchain profile: msvc (Windows)
# MSVC link.exe and lib.exe; never LLD

set(BM_TC_C_COMPILER "cl")
set(BM_TC_CXX_COMPILER "cl")
set(BM_TC_LINKER_TYPE "MSVC")
set(BM_TC_LINKER "link")
set(BM_TC_AR "lib")
set(BM_TC_RANLIB "")
set(BM_TC_NM "")
set(BM_TC_FORCE_LLD FALSE)
