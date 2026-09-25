#include "race_a.h"
#include "race_b.h"

int main(void)
{
	/* 100 + mid 11 + base 1. Each lib linked only RaceMid. */
	if (race_a_entry() != 112)
		return 1;
	if (race_b_entry() != 212)
		return 2;
	return 0;
}
