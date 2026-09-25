#include "trans_upper.h"
#include "trans_mid.h"

int trans_upper_entry(void)
{
	/* Mid only. Naming Base here would hide a missing transitive -l. */
	return 100 + trans_mid_tag();
}
