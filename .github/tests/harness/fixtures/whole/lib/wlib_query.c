#include "wlib.h"

int wlib_registered = 0;

int wlib_query(void) {
	return wlib_registered;
}
