#include "wlib.h"
#include "outlib.h"

/*
* WHOLE (wlib): ctor linked → wlib_query()==1, outlib_value()==11 → 0.
* plain (wlibplain): ctor dropped → wlib_query()==0 → 1.
*/
int main(void) {
	if (outlib_value() != 11)
		return 2;
	return wlib_query() == 1 ? 0 : 1;
}
