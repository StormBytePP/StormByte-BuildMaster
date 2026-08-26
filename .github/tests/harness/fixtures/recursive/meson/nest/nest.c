#include "nest.h"
#include <recursive/meson/mid.h>

int nest_value(void) {
    return mid_value() + 1;
}