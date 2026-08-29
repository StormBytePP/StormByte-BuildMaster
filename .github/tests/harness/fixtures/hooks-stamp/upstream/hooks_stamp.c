#include "hook_generated.h"

#if !defined(HOOK_STAMP) || HOOK_STAMP != 1
#	error "graph hook did not write hook_generated.h"
#endif

int hooks_stamp(void) {
	return HOOK_STAMP;
}

