#include "lfos.h"

/* Host must not need LINKFLAGS. Those stay in the nested OPTIONS. */
int main(void) {
	return lfos_value() != 1;
}
