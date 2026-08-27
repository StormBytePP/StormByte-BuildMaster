#include "leaf_b.h"

int leaf_b_on;

#if defined(_MSC_VER)
#  pragma section(".CRT$XCU", read)
static void __cdecl leaf_b_ctor(void);
__declspec(allocate(".CRT$XCU")) void (__cdecl *leaf_b_ctor_)(void) = leaf_b_ctor;
static void __cdecl leaf_b_ctor(void)
#else
static void leaf_b_ctor(void) __attribute__((constructor));
static void leaf_b_ctor(void)
#endif
{
	leaf_b_on = 1;
}

int leaf_b_flag(void) {
	return leaf_b_on;
}