#include "nest.h"
#include <recursive/cmake/mid.h>

int nest_value(void) {
    return mid_value() + 1;
}