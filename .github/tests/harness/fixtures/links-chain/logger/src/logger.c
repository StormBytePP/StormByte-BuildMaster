#include "stormbyte_logger.h"
#include "stormbyte_base.h"
int stormbyte_logger_tag(void) { return 10 + stormbyte_base_tag(); }
