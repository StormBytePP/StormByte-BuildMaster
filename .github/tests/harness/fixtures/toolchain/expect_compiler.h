/* Compile-time check: this TU must be built by HARNESS_EXPECT_FAMILY_*. */

#if defined(HARNESS_EXPECT_FAMILY_CLANG_CL)
#	if !(defined(__clang__) && defined(_MSC_VER))
#		error toolchain fixture: expected clang-cl
#	endif
#elif defined(HARNESS_EXPECT_FAMILY_MSVC)
#	if !defined(_MSC_VER) || defined(__clang__)
#		error toolchain fixture: expected MSVC
#	endif
#elif defined(HARNESS_EXPECT_FAMILY_CLANG)
#	if !defined(__clang__) || defined(_MSC_VER)
#		error toolchain fixture: expected Clang
#	endif
#elif defined(HARNESS_EXPECT_FAMILY_GCC)
#	if !defined(__GNUC__) || defined(__clang__)
#		error toolchain fixture: expected GCC
#	endif
#else
#	error toolchain fixture: missing HARNESS_EXPECT_FAMILY_*
#endif
