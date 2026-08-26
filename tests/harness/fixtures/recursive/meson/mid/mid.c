#include "mid.h"
#include <recursive/meson/leaf.h>

int mid_value(void) {
    return leaf_value() + 1;
}