#include "race_a.h"
#include "race_mid.h"
#include "race_base.h"

int race_a_entry(void)
{
	return 100 + race_mid_tag() + race_base_only();
}
