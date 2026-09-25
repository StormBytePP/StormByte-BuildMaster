#include "race_b.h"
#include "race_mid.h"
#include "race_base.h"

int race_b_entry(void)
{
	return 200 + race_mid_tag() + race_base_only();
}
