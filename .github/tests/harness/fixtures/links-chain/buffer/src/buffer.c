#include "stormbyte_buffer.h"
#include "stormbyte_logger.h"
int stormbyte_buffer_tag(void) { return 100 + stormbyte_logger_tag(); }
