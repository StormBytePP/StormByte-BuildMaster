#include "leaf_a.h"
#include "leaf_b.h"
#include "metaout.h"

int main(void) {
	if (metaout_value() != 7)
		return 2;
	if (leaf_a_flag() != 1)
		return 1;
	if (leaf_b_flag() != 1)
		return 1;
	return 0;
}
