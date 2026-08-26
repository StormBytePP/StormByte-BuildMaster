#include "second.h"
#include "first.h"

int second_value(void) {
	return first_value() + 1;
}