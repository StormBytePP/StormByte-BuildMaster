#include "lfunix.h"

/* UNIX cannot share --defsym with ld64. This binary proves the rpath
* flag is accepted. Presence of the token is check_linkflags.cmake. */
int main(void) {
	return lfunix_value() != 1;
}
