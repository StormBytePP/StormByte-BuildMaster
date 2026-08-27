#include "alib.h"
#include "aextra.h"
#include "blib.h"

int main(void) {
	return (alib_value() + aextra_value() + blib_value()) == 111 ? 0 : 1;
}
