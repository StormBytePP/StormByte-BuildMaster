#include "pc_lib.h"
#include "pc_dep.h"

int pc_lib_value(void) {
	return pc_dep_value() + 1;
}
