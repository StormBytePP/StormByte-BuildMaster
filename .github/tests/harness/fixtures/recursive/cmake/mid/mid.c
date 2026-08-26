#include "mid.h"
#include <recursive/cmake/leaf.h>

int mid_value(void) {
	return leaf_value() + 1;
}