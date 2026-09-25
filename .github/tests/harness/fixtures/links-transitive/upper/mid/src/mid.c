#include "trans_mid.h"
#include "trans_base.h"

int trans_mid_tag(void)
{
	return 10 + trans_base_only();
}
