#include "race_mid.h"
#include "race_base.h"

int race_mid_tag(void)
{
	return 10 + race_base_only();
}
