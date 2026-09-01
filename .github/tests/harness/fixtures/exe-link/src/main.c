#include "lib.h"
#include <stdio.h>
int main(void) { printf("exe-link %d\n", exe_leaf_flag()); return exe_leaf_flag() == 7 ? 0 : 1; }
