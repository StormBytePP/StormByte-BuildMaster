#include "expect_compiler.h"
#include "tc_mid_cmake.h"
#include <toolchain/tc_leaf_cmake.h>

int tc_mid_cmake_value(void) {
	return tc_leaf_cmake_value() + 1;
}
