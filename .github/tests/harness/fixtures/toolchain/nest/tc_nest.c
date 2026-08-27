#include "tc_nest.h"
#include <toolchain/tc_mid_cmake.h>
#include <toolchain/tc_mid_meson.h>

int tc_nest_value(void) {
	return tc_mid_cmake_value() + tc_mid_meson_value();
}
