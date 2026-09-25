#include "trans_leaf.h"

int main(void)
{
	/* 111 (upper) + 11 (mid) + 1 (base). Leaf linked only TransUpper. */
	if (trans_leaf_entry() != 123)
		return 1;
	return 0;
}
