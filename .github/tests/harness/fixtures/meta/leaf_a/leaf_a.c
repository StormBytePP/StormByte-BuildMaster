#include "leaf_a.h"

int leaf_a_on;

#if defined(_MSC_VER)
#  pragma section(".CRT$XCU", read)
static void __cdecl leaf_a_ctor(void);
__declspec(allocate(".CRT$XCU")) void (__cdecl *leaf_a_ctor_)(void) = leaf_a_ctor;
static void __cdecl leaf_a_ctor(void)
#else
static void leaf_a_ctor(void) __attribute__((constructor));
static void leaf_a_ctor(void)
#endif
{
	leaf_a_on = 1;
}

int leaf_a_flag(void)
{
	return leaf_a_on;
}
