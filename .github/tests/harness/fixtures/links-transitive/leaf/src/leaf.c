#include "trans_leaf.h"
#include "trans_upper.h"
#include "trans_mid.h"
#include "trans_base.h"

int trans_leaf_entry(void)
{
	return trans_upper_entry() + trans_mid_tag() + trans_base_only();
}
