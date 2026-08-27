#include "expect_compiler.h"
#include "tc_mid_meson.h"
#include "tc_leaf_meson.h"

int tc_mid_meson_value(void) {
	return tc_leaf_meson_value() + 1;
}
